#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v57b_domain_expert_pack_candidate_1000/candidate_001"
SUMMARY_CSV="$RESULTS_DIR/v57b_domain_expert_pack_candidate_1000_summary.csv"
DECISION_CSV="$RESULTS_DIR/v57b_domain_expert_pack_candidate_1000_decision.csv"

"$ROOT_DIR/experiments/run_v57b_domain_expert_pack_candidate_1000.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$ROOT_DIR" <<'PY'
import csv
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
root = Path(sys.argv[4])

PACK_TARGETS = {
    "codebase_qa": 250,
    "internal_docs_qa": 150,
    "ruler_niah": 150,
    "longbench_v2": 150,
    "incident_log_qa": 150,
    "product_manual_qa": 150,
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


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v57b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v57b_domain_expert_pack_candidate_ready": "1",
    "v57_domain_expert_packs_ready": "0",
    "domain_pack_rows": "6",
    "candidate_eval_rows": "1000",
    "source_span_rows": "1000",
    "answer_rows": "900",
    "abstain_rows": "100",
    "rubric_rows": "24",
    "failure_taxonomy_rows": "30",
    "policy_rows": "6",
    "expert_review_template_rows": "1000",
    "human_reviewed_rows": "0",
    "human_expert_review_ready": "0",
    "blind_eval_ready": "0",
    "expert_replacement_claim": "0",
    "v57_contract_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v57b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["domain-pack-candidate-scale", "source-span-binding", "abstain-negative-coverage", "rubric-policy-taxonomy"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v57b gate should pass: {gate}")
for gate in ["human-expert-review", "blind-eval-ready", "expert-replacement-claim", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v57b gate should remain blocked: {gate}")

required_files = [
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
    "source_v57_contract/domain_pack_target_rows.csv",
    "source_v57_contract/expert_review_contract_rows.csv",
    "source_v57_contract/domain_policy_gate_rows.csv",
    "source_v57_contract/V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "source_v57_contract/v57_domain_expert_packs_manifest.json",
    "source_v57_contract/sha256_manifest.csv",
    "source_v57_contract/v57_domain_expert_packs_contract_summary.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v57b artifact: {rel}")

eval_rows = read_csv(run_dir / "domain_pack_eval_rows.csv")
span_rows = read_csv(run_dir / "domain_pack_source_span_rows.csv")
pack_rows = read_csv(run_dir / "domain_pack_candidate_summary_rows.csv")
review_rows = read_csv(run_dir / "expert_review_template_rows.csv")
if len(eval_rows) != 1000 or len(span_rows) != 1000 or len(review_rows) != 1000:
    raise SystemExit("v57b should write 1000 eval/span/review template rows")
counts = Counter(row["domain_pack"] for row in eval_rows)
if counts != PACK_TARGETS:
    raise SystemExit(f"v57b domain distribution mismatch: {counts}")
if len({row["eval_id"] for row in eval_rows}) != 1000:
    raise SystemExit("v57b eval IDs should be unique")
if {row["source_span_id"] for row in eval_rows} != {row["source_span_id"] for row in span_rows}:
    raise SystemExit("v57b eval/span IDs should match")
if sum(int(row["negative_or_abstain"]) for row in eval_rows) != 100:
    raise SystemExit("v57b should include 100 abstain rows")
if any(row["human_review_status"] != "pending" or row["blind_eval_ready"] != "0" for row in eval_rows):
    raise SystemExit("v57b eval rows should remain review-pending")
span_by_id = {row["source_span_id"]: row for row in span_rows}
for row in eval_rows:
    span = span_by_id[row["source_span_id"]]
    if row["expected_answer_sha256"] != sha256_text(row["expected_answer"]):
        raise SystemExit("v57b expected answer hash mismatch")
    if span["evidence_text_sha256"] != sha256_text(span["evidence_text"]):
        raise SystemExit("v57b evidence hash mismatch")
    if span["source_file_sha256"] != sha256(root / span["path"]):
        raise SystemExit("v57b source file hash mismatch")
    if row["domain_pack"] != span["domain_pack"]:
        raise SystemExit("v57b eval/span domain mismatch")

pack_table = {row["domain_pack"]: row for row in pack_rows}
for domain_pack, target in PACK_TARGETS.items():
    row = pack_table[domain_pack]
    if int(row["candidate_eval_rows"]) != target or int(row["source_span_rows"]) != target:
        raise SystemExit(f"v57b pack summary mismatch: {domain_pack}")
    if row["human_reviewed_rows"] != "0" or row["status"] != "candidate-ready-review-pending":
        raise SystemExit(f"v57b pack should remain review-pending: {domain_pack}")

manifest = json.loads((run_dir / "v57b_domain_expert_pack_candidate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v57b_domain_expert_pack_candidate_ready") != 1 or manifest.get("v57_domain_expert_packs_ready") != 0:
    raise SystemExit("v57b manifest readiness mismatch")
if manifest.get("domain_counts") != PACK_TARGETS:
    raise SystemExit("v57b manifest domain counts mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v57b sha256 mismatch: {rel}")
if len([path for path in sha_rows if path.startswith("domain_pack_source_spans/")]) != 1000:
    raise SystemExit("v57b sha manifest should include 1000 source span files")

boundary = (run_dir / "V57B_DOMAIN_EXPERT_PACK_CANDIDATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "1000-row source-span-bound candidate set",
    "human_expert_review_ready=0",
    "blind_eval_ready=0",
    "Do not publish domain-expert, expert-replacement, or release claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v57b boundary missing {snippet}")
PY

echo "v57b domain expert pack candidate 1000 smoke passed"
