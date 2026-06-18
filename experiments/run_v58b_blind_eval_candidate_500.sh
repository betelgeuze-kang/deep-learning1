#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v58b_blind_eval_candidate_500"
RUN_ID="${V58B_RUN_ID:-candidate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

set +e
"$ROOT_DIR/experiments/run_v58_blind_eval_contract.sh" >/dev/null 2>"$RUN_DIR/v58_dependency_probe_stderr.txt"
V58_STATUS=$?
set -e

if [ "$V58_STATUS" -ne 0 ]; then
  python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$V58_STATUS" <<'PY'
import csv
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
upstream_status = sys.argv[5]
probe_path = run_dir / "v58_dependency_probe_stderr.txt"


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


missing = []
if probe_path.is_file():
    for line in probe_path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("missing_v57_artifact="):
            missing.append(line.split("=", 1)[1])
if not missing:
    missing = [
        str(root / "results/v58_blind_eval_contract_summary.csv"),
        str(root / "results/v58_blind_eval_contract/contract_001/blind_eval_gate_rows.csv"),
    ]

blocker_rows = [
    {
        "missing_dependency_artifact": artifact,
        "dependency_stage": "v57-domain-expert-pack-contract" if "v57_domain_expert_packs_contract" in artifact else "v58-blind-eval-contract",
        "required_for": "v58b-blind-eval-candidate-500",
        "upstream_runner": "run_v58_blind_eval_contract.sh",
        "upstream_status": upstream_status,
        "implicit_rebuild_allowed": "0",
        "approval_required": "1",
        "network_or_download_risk": "1",
        "fixture_allowed": "0",
        "tests_only_merge_condition": "0",
        "claim_boundary_status": "blocked-until-v57-v58-seed-artifact-present",
        "validation_command": "V58_ALLOW_V57_REBUILD=1 ./experiments/test_v58b_blind_eval_candidate_500.sh",
    }
    for artifact in missing
]
write_csv(
    run_dir / "v58b_dependency_blocker_rows.csv",
    [
        "missing_dependency_artifact",
        "dependency_stage",
        "required_for",
        "upstream_runner",
        "upstream_status",
        "implicit_rebuild_allowed",
        "approval_required",
        "network_or_download_risk",
        "fixture_allowed",
        "tests_only_merge_condition",
        "claim_boundary_status",
        "validation_command",
    ],
    blocker_rows,
)

missing_v57 = sum(1 for row in blocker_rows if row["dependency_stage"] == "v57-domain-expert-pack-contract")
summary = {
    "v58b_blind_eval_candidate_ready": "0",
    "v58_ready": "0",
    "v58b_dependency_blocker_ready": "1",
    "missing_dependency_artifact_rows": str(len(blocker_rows)),
    "missing_v57_dependency_artifact_rows": str(missing_v57),
    "implicit_dependency_rebuild_allowed": "0",
    "dependency_rebuild_approval_required": "1",
    "network_or_download_approval_required": "1",
    "frozen_query_rows": "0",
    "target_blind_eval_rows": "500",
    "blind_system_rows": "0",
    "blind_response_template_rows": "0",
    "actual_blind_response_rows": "0",
    "reviewer_packet_template_rows": "0",
    "sealed_answer_key_rows": "0",
    "sealed_identity_key_ready": "0",
    "query_freeze_ready": "0",
    "pre_output_query_selection_verified": "0",
    "same_evidence_budget_ready": "0",
    "reviewer_packet_anonymous": "0",
    "human_blind_review_ready": "0",
    "inter_rater_rows_ready": "0",
    "required_30b_blind_response_ready": "0",
    "required_70b_blind_response_ready": "0",
    "optional_100b_plus_blind_response_status": "blocked-until-v58b-seed",
    "v58_blind_eval_contract_ready": "0",
    "v57b_domain_expert_pack_candidate_ready": "0",
    "v58_full_blind_eval_ready": "0",
    "real_release_package_ready": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("dependency-blocker-artifact", "pass", "missing v57/v58 seed dependency is recorded as a replayable blocker artifact"),
    ("v58-contract-input", "blocked", "v58 contract is unavailable because implicit v57 regeneration is refused"),
    ("v57b-candidate-input", "blocked", "v57b candidate seed rows are unavailable without approved v57 dependency rebuild"),
    ("blind-query-freeze-candidate", "blocked", "no blind query freeze rows are fabricated without v58/v57b inputs"),
    ("source-span-binding", "blocked", "no source-span-bound blind rows are fabricated"),
    ("same-evidence-budget", "blocked", "no blind systems or budgets are materialized"),
    ("reviewer-packet-anonymization", "blocked", "no reviewer packets are materialized"),
    ("sealed-identity-key", "blocked", "no sealed identity rows are materialized"),
    ("30b-blind-response-row", "blocked", "30B blind response rows are missing"),
    ("70b-blind-response-row", "blocked", "70B blind response rows are missing"),
    ("100b-plus-blind-response-row", "blocked", "100B+ blind response rows are missing or deferred"),
    ("human-blind-review", "blocked", "human blind review rows are missing"),
    ("v58-full-blind-eval", "blocked", "v58 blind eval is incomplete"),
    ("real-release-package", "blocked", "v58b dependency blocker is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V58B_BLIND_EVAL_CANDIDATE_DEPENDENCY_BLOCKER.md").write_text(
    "# v58b Blind Eval Candidate Dependency Blocker\n\n"
    "The v58b blind-eval candidate artifact did not run because required v58/v57 seed artifacts are missing. "
    "The script refuses implicit regeneration so that public benchmark/source refresh, seed, and blind-eval protocol changes cannot happen silently.\n\n"
    f"- missing_dependency_artifact_rows={len(blocker_rows)}\n"
    f"- missing_v57_dependency_artifact_rows={missing_v57}\n"
    "- implicit_dependency_rebuild_allowed=0\n"
    "- dependency_rebuild_approval_required=1\n"
    "- network_or_download_approval_required=1\n"
    "- frozen_query_rows=0\n"
    "- v58_full_blind_eval_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: v58b dependency blocker artifact for missing blind-query seed replay evidence.\n\n"
    "Blocked wording: v58b candidate artifact ready, v58 blind-eval complete, public comparison result, or v1.0 release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v58b-blind-eval-candidate-dependency-blocker",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v58b_blind_eval_candidate_ready": 0,
    "v58_ready": 0,
    "v58b_dependency_blocker_ready": 1,
    "missing_dependency_artifact_rows": len(blocker_rows),
    "missing_v57_dependency_artifact_rows": missing_v57,
    "implicit_dependency_rebuild_allowed": 0,
    "dependency_rebuild_approval_required": 1,
    "network_or_download_approval_required": 1,
    "v58_full_blind_eval_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v58b_blind_eval_candidate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "v58b_dependency_blocker_rows.csv",
    "v58_dependency_probe_stderr.txt",
    "V58B_BLIND_EVAL_CANDIDATE_DEPENDENCY_BLOCKER.md",
    "v58b_blind_eval_candidate_manifest.json",
]
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v58b_blind_eval_candidate_dependency_blocker_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
  exit 0
fi
"$ROOT_DIR/experiments/run_v57b_domain_expert_pack_candidate_1000.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v58_dir = results / "v58_blind_eval_contract" / "contract_001"
v57b_dir = results / "v57b_domain_expert_pack_candidate_1000" / "candidate_001"
v58_summary = list(csv.DictReader((results / "v58_blind_eval_contract_summary.csv").open(newline="", encoding="utf-8")))[0]
v57b_summary = list(csv.DictReader((results / "v57b_domain_expert_pack_candidate_1000_summary.csv").open(newline="", encoding="utf-8")))[0]

DOMAIN_TARGETS = {
    "codebase_qa": 180,
    "internal_docs_qa": 80,
    "ruler_niah": 80,
    "longbench_v2": 80,
    "incident_log_qa": 40,
    "product_manual_qa": 40,
}


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
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
    return dst


def rel(path):
    return str(path.relative_to(root))


for relpath in [
    "blind_system_mapping_rows.csv",
    "blind_eval_query_contract_rows.csv",
    "blind_evaluator_contract_rows.csv",
    "blind_eval_gate_rows.csv",
    "V58_BLIND_EVAL_BOUNDARY.md",
    "v58_blind_eval_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v58_dir / relpath, f"source_v58/{relpath}")
copy(results / "v58_blind_eval_contract_summary.csv", "source_v58/v58_blind_eval_contract_summary.csv")

for relpath in [
    "domain_pack_eval_rows.csv",
    "domain_pack_source_span_rows.csv",
    "domain_pack_candidate_summary_rows.csv",
    "domain_pack_policy_rows.csv",
    "domain_pack_rubric_rows.csv",
    "domain_pack_failure_taxonomy_rows.csv",
    "expert_review_template_rows.csv",
    "V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md",
    "v57b_domain_expert_pack_candidate_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v57b_dir / relpath, f"source_v57b/{relpath}")
copy(results / "v57b_domain_expert_pack_candidate_1000_summary.csv", "source_v57b/v57b_domain_expert_pack_candidate_1000_summary.csv")

eval_rows = read_csv(v57b_dir / "domain_pack_eval_rows.csv")
span_rows = read_csv(v57b_dir / "domain_pack_source_span_rows.csv")
span_by_eval = {row["eval_id"]: row for row in span_rows}
by_domain = defaultdict(list)
for row in eval_rows:
    by_domain[row["domain_pack"]].append(row)

selected = []
for domain, target in DOMAIN_TARGETS.items():
    domain_rows = sorted(by_domain[domain], key=lambda row: row["eval_id"])
    selected.extend(domain_rows[:target])
if len(selected) != 500:
    raise SystemExit(f"expected 500 selected blind queries, got {len(selected)}")

blind_systems = read_csv(v58_dir / "blind_system_mapping_rows.csv")
blind_systems = [row for row in blind_systems if row["source_system_id"] in {"D", "E", "F", "G", "H"}]

query_rows = []
answer_key_rows = []
response_template_rows = []
reviewer_packet_rows = []
adjudication_rows = []
resource_budget_rows = []

for system in blind_systems:
    resource_budget_rows.append(
        {
            "evidence_budget_id": f"budget_{system['blind_system_id']}",
            "blind_system_id": system["blind_system_id"],
            "max_source_spans": 1,
            "source_span_bound_only": 1,
            "same_query_set": 1,
            "same_context_budget_bytes": 512,
            "same_citation_requirement": 1,
            "same_abstain_requirement": 1,
            "external_api_allowed": 1 if system["source_system_id"] == "F" else 0,
            "credential_redaction_required": 1,
        }
    )

for index, row in enumerate(selected, start=1):
    blind_eval_id = f"v58b_{index:04d}"
    span = span_by_eval[row["eval_id"]]
    source_path = root / span["path"]
    query_rows.append(
        {
            "blind_eval_id": blind_eval_id,
            "source_eval_id": row["eval_id"],
            "domain_pack": row["domain_pack"],
            "question": row["question"],
            "question_sha256": sha256_text(row["question"]),
            "source_span_id": span["source_span_id"],
            "source_span_path": span["path"],
            "source_file_sha256": sha256(source_path),
            "expected_behavior": row["expected_behavior"],
            "negative_or_abstain": row["negative_or_abstain"],
            "selection_order": index,
            "query_selected_before_outputs": 1,
            "system_outputs_observed_before_freeze": 0,
            "reviewer_identity_hidden": 1,
            "same_evidence_budget_required": 1,
        }
    )
    answer_key_rows.append(
        {
            "blind_eval_id": blind_eval_id,
            "source_eval_id": row["eval_id"],
            "domain_pack": row["domain_pack"],
            "expected_behavior": row["expected_behavior"],
            "expected_answer_sha256": row["expected_answer_sha256"],
            "source_span_id": span["source_span_id"],
            "source_file_sha256": sha256(source_path),
            "sealed_from_reviewer_packet": 1,
        }
    )
    for system in blind_systems:
        response_id = f"{blind_eval_id}_{system['blind_system_id']}"
        placeholder_reason = "real-response-required"
        if system["source_system_id"] == "F":
            placeholder_reason = "optional-hosted-response-or-final-deferral-required"
        response_template_rows.append(
            {
                "blind_response_id": response_id,
                "blind_eval_id": blind_eval_id,
                "blind_system_id": system["blind_system_id"],
                "source_system_id": system["source_system_id"],
                "evidence_budget_id": f"budget_{system['blind_system_id']}",
                "response_text": "",
                "citation_source_span_id": "",
                "resource_trace_path": "",
                "supplied_response_ready": 0,
                "identity_hidden_from_reviewer": 1,
                "placeholder_reason": placeholder_reason,
            }
        )
        reviewer_packet_rows.append(
            {
                "review_packet_row_id": f"{response_id}_review",
                "blind_response_id": response_id,
                "blind_eval_id": blind_eval_id,
                "blind_system_id": system["blind_system_id"],
                "domain_pack": row["domain_pack"],
                "question": row["question"],
                "response_text": "",
                "citation_source_span_id": "",
                "reviewer_score_correctness": "",
                "reviewer_score_citation": "",
                "reviewer_score_abstention": "",
                "reviewer_score_policy": "",
                "review_decision": "pending-blind-response",
                "identity_hidden_from_reviewer": 1,
            }
        )
        adjudication_rows.append(
            {
                "adjudication_row_id": f"{response_id}_adjudication",
                "blind_response_id": response_id,
                "reviewer_a_decision": "",
                "reviewer_b_decision": "",
                "adjudicated_decision": "",
                "inter_rater_ready": 0,
                "adjudication_ready": 0,
            }
        )

write_csv(run_dir / "blind_query_freeze_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "sealed_answer_key_rows.csv", list(answer_key_rows[0].keys()), answer_key_rows)
write_csv(run_dir / "blind_response_template_rows.csv", list(response_template_rows[0].keys()), response_template_rows)
write_csv(run_dir / "blind_reviewer_packet_template_rows.csv", list(reviewer_packet_rows[0].keys()), reviewer_packet_rows)
write_csv(run_dir / "blind_adjudication_template_rows.csv", list(adjudication_rows[0].keys()), adjudication_rows)
write_csv(run_dir / "blind_evidence_budget_rows.csv", list(resource_budget_rows[0].keys()), resource_budget_rows)

sealed_identity_rows = [
    {
        "blind_system_id": row["blind_system_id"],
        "source_system_id": row["source_system_id"],
        "source_system_name": row["source_system_name"],
        "sealed_until_scoring_complete": 1,
        "identity_hidden_from_reviewer": row["identity_hidden_from_reviewer"],
    }
    for row in blind_systems
]
write_csv(run_dir / "sealed_identity_key_rows.csv", list(sealed_identity_rows[0].keys()), sealed_identity_rows)

pack_summary_rows = []
counts = Counter(row["domain_pack"] for row in query_rows)
for domain, target in DOMAIN_TARGETS.items():
    pack_summary_rows.append(
        {
            "domain_pack": domain,
            "frozen_query_rows": counts[domain],
            "target_query_rows": target,
            "source_span_bound": 1,
            "query_selected_before_outputs": 1,
            "human_reviewed_rows": 0,
        }
    )
write_csv(run_dir / "blind_domain_summary_rows.csv", list(pack_summary_rows[0].keys()), pack_summary_rows)

rubric_rows = [
    ("correctness", "answer must match sealed source-span-supported key or abstain when unsupported"),
    ("citation", "answer claims must cite the supplied source span"),
    ("abstention", "unsupported rows must abstain instead of fabricating"),
    ("policy", "domain policy and wrong-answer guard must be obeyed"),
    ("resource", "latency/memory/cost are scored outside blind answer quality"),
]
write_csv(
    run_dir / "blind_scoring_rubric_rows.csv",
    ["rubric_axis", "pass_condition", "human_review_required"],
    [{"rubric_axis": axis, "pass_condition": condition, "human_review_required": 1} for axis, condition in rubric_rows],
)

query_freeze_ready = int(
    len(query_rows) == 500
    and counts == DOMAIN_TARGETS
    and all(int(row["query_selected_before_outputs"]) == 1 for row in query_rows)
    and all(int(row["system_outputs_observed_before_freeze"]) == 0 for row in query_rows)
)
same_budget_ready = int(
    len(resource_budget_rows) == 5
    and len({row["same_context_budget_bytes"] for row in resource_budget_rows}) == 1
    and all(int(row["source_span_bound_only"]) == 1 for row in resource_budget_rows)
)
reviewer_packet_anonymous = int(
    "source_system_id" not in reviewer_packet_rows[0]
    and all(int(row["identity_hidden_from_reviewer"]) == 1 for row in reviewer_packet_rows)
)

summary = {
    "v58b_blind_eval_candidate_ready": int(query_freeze_ready and same_budget_ready and reviewer_packet_anonymous),
    "v58_ready": 0,
    "frozen_query_rows": len(query_rows),
    "target_blind_eval_rows": 500,
    "blind_system_rows": len(blind_systems),
    "blind_response_template_rows": len(response_template_rows),
    "actual_blind_response_rows": 0,
    "reviewer_packet_template_rows": len(reviewer_packet_rows),
    "sealed_answer_key_rows": len(answer_key_rows),
    "sealed_identity_key_ready": 1,
    "query_freeze_ready": query_freeze_ready,
    "pre_output_query_selection_verified": query_freeze_ready,
    "same_evidence_budget_ready": same_budget_ready,
    "reviewer_packet_anonymous": reviewer_packet_anonymous,
    "human_blind_review_ready": 0,
    "inter_rater_rows_ready": 0,
    "required_30b_blind_response_ready": 0,
    "required_70b_blind_response_ready": 0,
    "optional_100b_plus_blind_response_status": "deferred-with-reason",
    "v58_blind_eval_contract_ready": int(v58_summary.get("v58_blind_eval_contract_ready", "0")),
    "v57b_domain_expert_pack_candidate_ready": int(v57b_summary.get("v57b_domain_expert_pack_candidate_ready", "0")),
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("blind-query-freeze-candidate", "pass" if query_freeze_ready else "blocked", f"frozen_query_rows={len(query_rows)}"),
    ("source-span-binding", "pass" if all(row["source_file_sha256"] for row in query_rows) else "blocked", "all frozen queries bind source span hashes"),
    ("same-evidence-budget", "pass" if same_budget_ready else "blocked", f"budget_rows={len(resource_budget_rows)}"),
    ("reviewer-packet-anonymization", "pass" if reviewer_packet_anonymous else "blocked", f"reviewer_packet_rows={len(reviewer_packet_rows)}"),
    ("sealed-identity-key", "pass", f"sealed_identity_rows={len(sealed_identity_rows)}"),
    ("30b-blind-response-row", "blocked", "30B LLM+RAG blind responses are not supplied"),
    ("70b-blind-response-row", "blocked", "70B LLM+RAG blind responses are not supplied"),
    ("100b-plus-blind-response-row", "blocked", "100B+ hosted/API blind responses are missing or deferred"),
    ("human-blind-review", "blocked", "human blind review and inter-rater rows are not supplied"),
    ("v58-full-blind-eval", "blocked", "candidate freeze is ready but response/review rows are missing"),
    ("real-release-package", "blocked", "v58b candidate packet is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md").write_text(
    "# v58b Blind Eval Candidate Boundary\n\n"
    "This packet freezes 500 source-span-bound candidate queries and blind reviewer packet templates. "
    "It is not the completed blind evaluation versus 30B-150B-class systems.\n\n"
    f"- frozen_query_rows={len(query_rows)}\n"
    f"- blind_response_template_rows={len(response_template_rows)}\n"
    f"- actual_blind_response_rows=0\n"
    f"- reviewer_packet_template_rows={len(reviewer_packet_rows)}\n"
    "- query_selected_before_outputs=1\n"
    "- system_outputs_observed_before_freeze=0\n"
    "- human_blind_review_ready=0\n"
    "- inter_rater_rows_ready=0\n\n"
    "Still blocked:\n\n"
    "- 30B and 70B LLM+RAG blind responses\n"
    "- optional 100B+ hosted/API blind responses or final deferral\n"
    "- human blind review and adjudication\n"
    "- v59 one-command replay over real v52-v58 rows\n\n"
    "Do not publish blind-eval wins, expert-replacement claims, or 30B-150B comparison claims from this candidate packet.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v58b-blind-eval-candidate-500",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v58b_blind_eval_candidate_ready": summary["v58b_blind_eval_candidate_ready"],
    "v58_ready": 0,
    "domain_counts": dict(counts),
    "frozen_query_rows": len(query_rows),
    "blind_system_rows": len(blind_systems),
    "blind_response_template_rows": len(response_template_rows),
    "actual_blind_response_rows": 0,
    "reviewer_packet_template_rows": len(reviewer_packet_rows),
    "source_v58_summary_sha256": sha256(results / "v58_blind_eval_contract_summary.csv"),
    "source_v57b_summary_sha256": sha256(results / "v57b_domain_expert_pack_candidate_1000_summary.csv"),
    "human_blind_review_ready": 0,
    "inter_rater_rows_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v58b_blind_eval_candidate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "blind_query_freeze_rows.csv",
    "sealed_answer_key_rows.csv",
    "blind_response_template_rows.csv",
    "blind_reviewer_packet_template_rows.csv",
    "blind_adjudication_template_rows.csv",
    "blind_evidence_budget_rows.csv",
    "sealed_identity_key_rows.csv",
    "blind_domain_summary_rows.csv",
    "blind_scoring_rubric_rows.csv",
    "V58B_BLIND_EVAL_CANDIDATE_BOUNDARY.md",
    "v58b_blind_eval_candidate_manifest.json",
    "source_v58/blind_system_mapping_rows.csv",
    "source_v58/blind_eval_query_contract_rows.csv",
    "source_v58/blind_evaluator_contract_rows.csv",
    "source_v58/blind_eval_gate_rows.csv",
    "source_v58/V58_BLIND_EVAL_BOUNDARY.md",
    "source_v58/v58_blind_eval_manifest.json",
    "source_v58/sha256_manifest.csv",
    "source_v58/v58_blind_eval_contract_summary.csv",
    "source_v57b/domain_pack_eval_rows.csv",
    "source_v57b/domain_pack_source_span_rows.csv",
    "source_v57b/domain_pack_candidate_summary_rows.csv",
    "source_v57b/domain_pack_policy_rows.csv",
    "source_v57b/domain_pack_rubric_rows.csv",
    "source_v57b/domain_pack_failure_taxonomy_rows.csv",
    "source_v57b/expert_review_template_rows.csv",
    "source_v57b/V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md",
    "source_v57b/v57b_domain_expert_pack_candidate_manifest.json",
    "source_v57b/sha256_manifest.csv",
    "source_v57b/v57b_domain_expert_pack_candidate_1000_summary.csv",
]
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v58b_blind_eval_candidate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
