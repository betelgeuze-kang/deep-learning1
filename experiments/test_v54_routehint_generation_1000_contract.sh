#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v54_routehint_generation_1000_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v54_routehint_generation_1000_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v54_routehint_generation_1000_contract_decision.csv"

"$ROOT_DIR/experiments/run_v54_routehint_generation_1000_contract.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])

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
    raise SystemExit(f"expected one v54 contract summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v54_generation_1000_contract_ready": "1",
    "v54_generation_1000_ready": "0",
    "target_generation_rows": "1000",
    "seed_generation_rows": "24",
    "mainline_generation_rows": "4",
    "missing_generation_rows": "976",
    "domain_target_rows": "6",
    "attention_blocks": "0",
    "transformer_blocks": "0",
    "raw_prompt_context_appended_rows": "0",
    "proposal_hint_used_rows": "4",
    "missing_query_abstention_ready": "1",
    "citation_accuracy_contract_ready": "1",
    "grounding_contract_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v54 contract {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v54-generation-1000-contract", "v48-seed-evidence", "v54-mainline-invariants"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v54 contract gate should pass: {gate}")
for gate in ["generation-row-target", "citation-grounding-target", "real-release-package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v54 contract gate should remain blocked: {gate}")

required_files = [
    "domain_generation_target_rows.csv",
    "generation_invariant_rows.csv",
    "artifact_contract_rows.csv",
    "V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md",
    "v54_routehint_generation_1000_manifest.json",
    "sha256_manifest.csv",
    "source_v48/route_memory_evidence_rows.csv",
    "source_v48/compact_route_hint_rows.csv",
    "source_v48/tiny_generator_input_rows.csv",
    "source_v48/grounded_generation_rows.csv",
    "source_v48/V48_MULTI_DOMAIN_GENERATOR_BOUNDARY.md",
    "source_v48/v48_multi_domain_generator_manifest.json",
    "source_v48/sha256_manifest.csv",
    "source_v54_mainline/route_memory_evidence_rows.csv",
    "source_v54_mainline/compact_route_hint_rows.csv",
    "source_v54_mainline/generator_input_rows.csv",
    "source_v54_mainline/grounded_generation_rows.csv",
    "source_v54_mainline/citation_rows.csv",
    "source_v54_mainline/abstain_rows.csv",
    "source_v54_mainline/unsupported_claim_rows.csv",
    "source_v54_mainline/generation_metrics.json",
    "source_v54_mainline/generator_boundary.md",
    "source_v54_mainline/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v54 contract artifact: {rel}")

domain_rows = read_csv(run_dir / "domain_generation_target_rows.csv")
if len(domain_rows) != 6:
    raise SystemExit("v54 contract should cover six domain targets")
if sum(int(row["target_generation_rows"]) for row in domain_rows) != 1000:
    raise SystemExit("v54 domain targets should sum to 1000")
if sum(int(row["missing_generation_rows"]) for row in domain_rows) != 970:
    raise SystemExit("v54 per-domain missing rows should reflect current seed distribution")
for row in domain_rows:
    for field in ["route_memory_evidence_required", "compact_routehint_required", "citation_required", "abstain_required"]:
        if row[field] != "1":
            raise SystemExit(f"v54 domain target should require {field}")

invariants = read_csv(run_dir / "generation_invariant_rows.csv")
if len(invariants) != 8 or any(row["status"] != "pass" for row in invariants):
    raise SystemExit("v54 invariants should all pass on the current seed")
by_inv = {row["invariant"]: row for row in invariants}
for inv in ["attention_blocks", "transformer_blocks", "raw_prompt_context_appended_rows"]:
    if by_inv[inv]["observed_value"] != "0":
        raise SystemExit(f"v54 invariant should stay zero: {inv}")

artifact_contract = {row["artifact"] for row in read_csv(run_dir / "artifact_contract_rows.csv")}
for artifact in ["route_memory_evidence_rows", "compact_route_hint_rows", "generator_input_rows", "grounded_generation_rows", "citation_rows", "abstain_rows", "unsupported_claim_rows", "resource_rows", "sha256_manifest"]:
    if artifact not in artifact_contract:
        raise SystemExit(f"v54 artifact contract missing {artifact}")

manifest = json.loads((run_dir / "v54_routehint_generation_1000_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v54_generation_1000_contract_ready") != 1 or manifest.get("v54_generation_1000_ready") != 0:
    raise SystemExit("v54 manifest readiness boundary mismatch")
if manifest.get("missing_generation_rows") != 976:
    raise SystemExit("v54 manifest missing-generation count mismatch")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v54 sha256 mismatch: {rel}")

boundary = (run_dir / "V54_ROUTEHINT_GENERATION_1000_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed 1000+ row generation run",
    "missing_generation_rows=976",
    "no attention blocks",
    "no raw prompt context appended",
    "Do not publish v54 generation-mainline claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v54 boundary missing {snippet}")
PY

echo "v54 RouteHint generation 1000-row contract smoke passed"
