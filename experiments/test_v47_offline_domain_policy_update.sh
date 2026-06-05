#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
POLICY_DIR="$RESULTS_DIR/v47_offline_domain_policy_update/policy_001"
RETURN_DIR="$POLICY_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v47_offline_domain_policy_update_summary.csv"
DECISION_CSV="$RESULTS_DIR/v47_offline_domain_policy_update_decision.csv"

"$ROOT_DIR/experiments/run_v47_offline_domain_policy_update.sh" >/dev/null

python3 - "$ROOT_DIR" "$POLICY_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
policy_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v47 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_ones = [
    "v47_offline_domain_policy_update_ready",
    "offline_only",
    "privacy_review_ready",
    "resource_envelope_ready",
    "v18_closed_corpus_poc_actual_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v47 {field}: expected 1, got {summary.get(field)}")
expected_values = {
    "policy_rows": "15",
    "domain_count": "3",
    "learning_target_count": "5",
    "candidate_selection_rows": "3",
    "span_read_rows": "3",
    "hint_strength_rows": "3",
    "abstain_retry_rows": "3",
    "verifier_decision_rows": "3",
    "external_network_used": "0",
    "expert_replacement_claim": "0",
    "release_ready_claim": "0",
    "human_review_completed": "0",
    "real_release_package_ready": "0",
}
for field, expected in expected_values.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v47 {field}: expected {expected}, got {summary.get(field)}")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v47-offline-domain-policy-update",
    "domain-coverage",
    "learning-targets",
    "offline-only",
    "no-expert-replacement",
    "v18-commercial-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v47 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v47 should leave release blocked")

required_files = [
    "V47_OFFLINE_DOMAIN_POLICY_BOUNDARY.md",
    "offline_domain_policy_rows.csv",
    "offline_domain_policy.json",
    "policy_source_rows.csv",
    "v47_offline_domain_policy_manifest.json",
    "sha256_manifest.csv",
    "evidence/v18_offline_domain_policy_summary.csv",
    "evidence/v18_offline_domain_policy_decision.csv",
    "evidence/v46_source_verified_scorer_summary.csv",
    "commercial_return/domain_manifest.json",
    "commercial_return/corpus_manifest.json",
    "commercial_return/query_set.csv",
    "commercial_return/poc_result_rows.csv",
    "commercial_return/audit_trail.csv",
    "commercial_return/resource_envelope.json",
    "commercial_return/privacy_review.json",
    "commercial_return/acceptance_review.csv",
]
for rel in required_files:
    path = policy_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v47 missing artifact: {rel}")

manifest = json.loads((policy_dir / "v47_offline_domain_policy_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v47_offline_domain_policy_update_ready") != 1:
    raise SystemExit("v47 manifest should be ready")
if manifest.get("policy_rows") != 15 or manifest.get("domain_count") != 3 or manifest.get("learning_target_count") != 5:
    raise SystemExit("v47 manifest should record 15 rows over 3 domains and 5 targets")
if manifest.get("offline_only") != 1 or manifest.get("expert_replacement_claim") != 0 or manifest.get("release_ready_claim") != 0:
    raise SystemExit("v47 manifest should keep offline assistance boundary")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v47 manifest should keep review/release blocked")

policy = json.loads((policy_dir / "offline_domain_policy.json").read_text(encoding="utf-8"))
if policy.get("offline_only") != 1 or policy.get("external_network_used") != 0:
    raise SystemExit("v47 policy should be offline-only")
if set(policy.get("learning_targets", [])) != {"candidate_selection", "span_read", "hint_strength", "abstain_retry", "verifier_decision"}:
    raise SystemExit("v47 policy should include the five learning targets")

source_rows = read_csv(policy_dir / "policy_source_rows.csv")
policy_rows = read_csv(policy_dir / "offline_domain_policy_rows.csv")
if len(source_rows) != 3 or len(policy_rows) != 15:
    raise SystemExit("v47 should write 3 source rows and 15 policy rows")
if set(row["domain"] for row in source_rows) != {"codebase_qa", "longbench_v2", "source_verified_scorer"}:
    raise SystemExit("v47 source rows should cover the three domains")
for row in source_rows:
    path = root / row["summary_path"]
    if row["summary_sha256"] != sha256(path):
        raise SystemExit(f"v47 source hash mismatch: {row['domain']}")
    if row["source_ready"] != "1":
        raise SystemExit("v47 source rows should be ready")
for row in policy_rows:
    if row["offline_only"] != "1" or row["external_network_used"] != "0":
        raise SystemExit("v47 policy rows should be offline-only")
    if row["expert_replacement_claim"] != "0" or row["release_ready_claim"] != "0":
        raise SystemExit("v47 policy rows should not make expert/release claims")
    if row["policy_status"] != "active-offline":
        raise SystemExit("v47 policy rows should be active-offline")
for target, field in [
    ("candidate_selection", "candidate_selection_bound"),
    ("span_read", "span_read_bound"),
    ("hint_strength", "hint_strength_bound"),
    ("abstain_retry", "abstain_retry_bound"),
    ("verifier_decision", "verifier_decision_bound"),
]:
    rows = [row for row in policy_rows if row["learning_target"] == target and row[field] == "1"]
    if len(rows) != 3:
        raise SystemExit(f"v47 should bind {target} for all three domains")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 15:
    raise SystemExit("v47 domain should be codebase_qa with 15 queries")
if resource.get("offline_only") != 1 or resource.get("external_network_used") != 0:
    raise SystemExit("v47 resource envelope should be offline")
if privacy.get("privacy_review_ready") != 1:
    raise SystemExit("v47 privacy review should be ready")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 15 or len(poc_rows) != 15 or len(audit_rows) != 15:
    raise SystemExit("v47 query/result/audit rows should all be 15")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "audit_trail_bound"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v47 result rows should pass {field}")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v47 audit trail rows should pass")
if len(acceptance_rows) < 7 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v47 acceptance rows should pass")

with (policy_dir / "evidence" / "v18_offline_domain_policy_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v47 copied v18 summary should verify commercial PoC")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v47 copied v18 summary should keep release blocked")

boundary = (policy_dir / "V47_OFFLINE_DOMAIN_POLICY_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Start domain-specialized assistant behavior",
    "Candidate selection",
    "Verifier decision",
    "not expert replacement",
    "not release-ready product evidence",
]:
    if snippet not in boundary:
        raise SystemExit(f"v47 boundary missing: {snippet}")

with (policy_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v47 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(policy_dir / rel):
        raise SystemExit(f"v47 sha mismatch for {rel}")
PY

echo "v47 Offline Domain Policy Update smoke passed"
