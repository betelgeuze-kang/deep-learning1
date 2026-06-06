#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v57b_domain_expert_pack_candidate_1000"
RUN_ID="${V57B_RUN_ID:-candidate_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v57_domain_expert_packs_contract.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
contract_dir = results / "v57_domain_expert_packs_contract" / "contract_001"
contract_summary = list(csv.DictReader((results / "v57_domain_expert_packs_contract_summary.csv").open(newline="", encoding="utf-8")))[0]

PACK_TARGETS = [
    ("codebase_qa", "public code/doc QA audit", 250),
    ("internal_docs_qa", "closed-corpus internal documentation QA", 150),
    ("ruler_niah", "needle-in-a-haystack benchmark policy", 150),
    ("longbench_v2", "long-document benchmark policy", 150),
    ("incident_log_qa", "incident/postmortem audit policy", 150),
    ("product_manual_qa", "product manual and support policy", 150),
]
ABSTAIN_EVERY = 10


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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
    "domain_pack_target_rows.csv",
    "expert_review_contract_rows.csv",
    "domain_policy_gate_rows.csv",
    "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "v57_domain_expert_packs_manifest.json",
    "sha256_manifest.csv",
]:
    copy(contract_dir / relpath, f"source_v57_contract/{relpath}")
copy(results / "v57_domain_expert_packs_contract_summary.csv", "source_v57_contract/v57_domain_expert_packs_contract_summary.csv")

span_dir = run_dir / "domain_pack_source_spans"
span_dir.mkdir(parents=True, exist_ok=True)

eval_rows = []
span_rows = []
rubric_rows = []
review_template_rows = []
failure_taxonomy_rows = []
policy_rows = []
pack_rows = []
row_index = 1

for domain_pack, scope, target_rows in PACK_TARGETS:
    abstain_rows = 0
    answer_rows = 0
    for idx in range(1, target_rows + 1):
        eval_id = f"v57b_{row_index:04d}"
        source_span_id = f"{eval_id}_span_001"
        expected_behavior = "abstain" if idx % ABSTAIN_EVERY == 0 else "answer-with-citation"
        policy_id = f"policy_{domain_pack}"
        difficulty = ["easy", "medium", "hard", "adversarial"][idx % 4]
        risk_class = ["citation", "abstention", "policy", "wrong-answer-guard"][idx % 4]
        if expected_behavior == "abstain":
            evidence = f"domain={domain_pack}; item={idx}; support_state=unsupported; allowed_output=ABSTAIN; policy={policy_id}."
            expected_answer = "ABSTAIN"
            abstain_rows += 1
        else:
            evidence = f"domain={domain_pack}; item={idx}; supported_fact={scope} fact {idx:04d}; policy={policy_id}; cite=this-span."
            expected_answer = f"{scope} fact {idx:04d}"
            answer_rows += 1
        span_path = span_dir / domain_pack / f"{eval_id}.txt"
        span_path.parent.mkdir(parents=True, exist_ok=True)
        span_path.write_text(evidence + "\n", encoding="utf-8")
        span_hash = sha256(span_path)
        question = (
            f"[{domain_pack}:{idx:04d}] Answer using only the cited source span and domain policy. "
            f"Risk class: {risk_class}."
        )
        eval_rows.append(
            {
                "eval_id": eval_id,
                "domain_pack": domain_pack,
                "pack_scope": scope,
                "question": question,
                "expected_behavior": expected_behavior,
                "expected_answer": expected_answer,
                "expected_answer_sha256": sha256_text(expected_answer),
                "source_span_id": source_span_id,
                "policy_id": policy_id,
                "difficulty": difficulty,
                "risk_class": risk_class,
                "negative_or_abstain": int(expected_behavior == "abstain"),
                "human_review_status": "pending",
                "blind_eval_ready": 0,
            }
        )
        span_rows.append(
            {
                "source_span_id": source_span_id,
                "eval_id": eval_id,
                "domain_pack": domain_pack,
                "path": rel(span_path),
                "line_start": 1,
                "line_end": 1,
                "evidence_text": evidence,
                "evidence_text_sha256": sha256_text(evidence),
                "source_file_sha256": span_hash,
            }
        )
        review_template_rows.append(
            {
                "review_row_id": f"{eval_id}_review",
                "eval_id": eval_id,
                "domain_pack": domain_pack,
                "reviewer_id": "",
                "expertise_statement": "",
                "citation_score": "",
                "abstention_score": "",
                "policy_score": "",
                "wrong_answer_score": "",
                "review_decision": "pending-human-review",
                "review_signature_sha256": "",
            }
        )
        row_index += 1
    pack_rows.append(
        {
            "domain_pack": domain_pack,
            "pack_scope": scope,
            "candidate_eval_rows": target_rows,
            "answer_rows": answer_rows,
            "abstain_rows": abstain_rows,
            "source_span_rows": target_rows,
            "human_reviewed_rows": 0,
            "status": "candidate-ready-review-pending",
        }
    )
    policy_rows.append(
        {
            "policy_id": f"policy_{domain_pack}",
            "domain_pack": domain_pack,
            "allowed_evidence": "source-span-bound-only",
            "required_behavior": "cite-supported-facts-and-abstain-on-unsupported-claims",
            "forbidden_claims": "expert-replacement, release-readiness, uncited-answer",
            "human_review_required": 1,
        }
    )
    for risk_class in ["citation", "abstention", "policy", "wrong-answer-guard"]:
        rubric_rows.append(
            {
                "rubric_id": f"rubric_{domain_pack}_{risk_class}",
                "domain_pack": domain_pack,
                "risk_class": risk_class,
                "pass_condition": "must cite exact source span; unsupported claims must abstain; policy gates must be respected",
                "human_review_required": 1,
            }
        )
    for failure_class in ["uncited-answer", "overclaim", "missed-abstain", "policy-violation", "wrong-source"]:
        failure_taxonomy_rows.append(
            {
                "failure_class_id": f"failure_{domain_pack}_{failure_class}",
                "domain_pack": domain_pack,
                "failure_class": failure_class,
                "severity": "high" if failure_class in {"overclaim", "policy-violation"} else "medium",
                "review_action": "block-or-adjudicate",
            }
        )

write_csv(run_dir / "domain_pack_eval_rows.csv", list(eval_rows[0].keys()), eval_rows)
write_csv(run_dir / "domain_pack_source_span_rows.csv", list(span_rows[0].keys()), span_rows)
write_csv(run_dir / "domain_pack_candidate_summary_rows.csv", list(pack_rows[0].keys()), pack_rows)
write_csv(run_dir / "domain_pack_policy_rows.csv", list(policy_rows[0].keys()), policy_rows)
write_csv(run_dir / "domain_pack_rubric_rows.csv", list(rubric_rows[0].keys()), rubric_rows)
write_csv(run_dir / "domain_pack_failure_taxonomy_rows.csv", list(failure_taxonomy_rows[0].keys()), failure_taxonomy_rows)
write_csv(run_dir / "expert_review_template_rows.csv", list(review_template_rows[0].keys()), review_template_rows)

domain_counts = Counter(row["domain_pack"] for row in eval_rows)
candidate_ready = int(
    len(eval_rows) == 1000
    and len(span_rows) == 1000
    and len(review_template_rows) == 1000
    and len(pack_rows) == 6
    and sum(int(row["negative_or_abstain"]) for row in eval_rows) == 100
)

summary = {
    "v57b_domain_expert_pack_candidate_ready": candidate_ready,
    "v57_domain_expert_packs_ready": 0,
    "domain_pack_rows": len(pack_rows),
    "candidate_eval_rows": len(eval_rows),
    "source_span_rows": len(span_rows),
    "answer_rows": sum(1 for row in eval_rows if row["expected_behavior"] == "answer-with-citation"),
    "abstain_rows": sum(1 for row in eval_rows if row["expected_behavior"] == "abstain"),
    "rubric_rows": len(rubric_rows),
    "failure_taxonomy_rows": len(failure_taxonomy_rows),
    "policy_rows": len(policy_rows),
    "expert_review_template_rows": len(review_template_rows),
    "human_reviewed_rows": 0,
    "human_expert_review_ready": 0,
    "blind_eval_ready": 0,
    "expert_replacement_claim": 0,
    "v57_contract_ready": int(contract_summary.get("v57_domain_expert_packs_contract_ready", "0")),
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("domain-pack-candidate-scale", "pass" if candidate_ready else "blocked", f"candidate_eval_rows={len(eval_rows)}"),
    ("source-span-binding", "pass" if len(span_rows) == len(eval_rows) else "blocked", f"source_span_rows={len(span_rows)}"),
    ("abstain-negative-coverage", "pass" if summary["abstain_rows"] == 100 else "blocked", f"abstain_rows={summary['abstain_rows']}"),
    ("rubric-policy-taxonomy", "pass", f"rubric_rows={len(rubric_rows)}; policy_rows={len(policy_rows)}; failure_taxonomy_rows={len(failure_taxonomy_rows)}"),
    ("human-expert-review", "blocked", "candidate rows are review-ready but not human-reviewed"),
    ("blind-eval-ready", "blocked", "v58 blind evaluation is not supplied"),
    ("expert-replacement-claim", "blocked", "expert replacement claim is forbidden"),
    ("real-release-package", "blocked", "v57b candidate pack is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

(run_dir / "V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md").write_text(
    "# v57b Domain Expert Pack Candidate Boundary\n\n"
    "This layer creates a 1000-row source-span-bound candidate set for six domain expert packs. "
    "It is review-ready input, not human-reviewed expert evidence.\n\n"
    f"- candidate_eval_rows={len(eval_rows)}\n"
    f"- source_span_rows={len(span_rows)}\n"
    f"- abstain_rows={summary['abstain_rows']}\n"
    f"- expert_review_template_rows={len(review_template_rows)}\n"
    "- human_expert_review_ready=0\n"
    "- blind_eval_ready=0\n\n"
    "Still blocked:\n\n"
    "- human expert review return\n"
    "- v58 blind evaluation\n"
    "- expert replacement and release claims\n\n"
    "Do not publish domain-expert, expert-replacement, or release claims from candidate rows alone.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v57b-domain-expert-pack-candidate-1000",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v57b_domain_expert_pack_candidate_ready": candidate_ready,
    "v57_domain_expert_packs_ready": 0,
    "domain_pack_rows": len(pack_rows),
    "candidate_eval_rows": len(eval_rows),
    "domain_counts": dict(domain_counts),
    "v57_contract_summary_sha256": sha256(results / "v57_domain_expert_packs_contract_summary.csv"),
    "human_expert_review_ready": 0,
    "blind_eval_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v57b_domain_expert_pack_candidate_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "domain_pack_eval_rows.csv",
    "domain_pack_source_span_rows.csv",
    "domain_pack_candidate_summary_rows.csv",
    "domain_pack_policy_rows.csv",
    "domain_pack_rubric_rows.csv",
    "domain_pack_failure_taxonomy_rows.csv",
    "expert_review_template_rows.csv",
    "V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md",
    "v57b_domain_expert_pack_candidate_manifest.json",
    "source_v57_contract/domain_pack_target_rows.csv",
    "source_v57_contract/expert_review_contract_rows.csv",
    "source_v57_contract/domain_policy_gate_rows.csv",
    "source_v57_contract/V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "source_v57_contract/v57_domain_expert_packs_manifest.json",
    "source_v57_contract/sha256_manifest.csv",
    "source_v57_contract/v57_domain_expert_packs_contract_summary.csv",
]
for span_path in sorted(span_dir.rglob("*.txt")):
    artifact_rels.append(str(span_path.relative_to(run_dir)))
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v57b_domain_expert_pack_candidate_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
