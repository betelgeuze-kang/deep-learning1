#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61gg_post_gf_real_authority_binding_guard"
RUN_DIR="$RESULTS_DIR/$PREFIX/guard_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
GUARD_DIR="$RUN_DIR/real_authority_binding_guard"

V61GG_REUSE_EXISTING="${V61GG_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61gg_post_gf_real_authority_binding_guard.sh" >/dev/null

"$GUARD_DIR/VERIFY_REAL_AUTHORITY_BINDING_GUARD.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$GUARD_DIR" <<'PY'
import csv
import hashlib
import json
import os
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
guard_dir = Path(sys.argv[4])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v61gg_post_gf_real_authority_binding_guard_ready": "1",
    "v61gf_post_ge_dual_partial_return_replay_admission_ready": "1",
    "v53_authority_marker_exists": "0",
    "v53_authority_file_exists": "0",
    "v53_authority_binding_ready": "0",
    "v61_authority_marker_exists": "0",
    "v61_authority_file_exists": "0",
    "v61_authority_binding_ready": "0",
    "dual_authority_binding_ready": "0",
    "v61gf_row_acceptance_ready": "0",
    "v61gf_generation_execution_admission_ready": "0",
    "v61gf_dual_external_return_real_ready": "0",
    "v61gf_real_return_replay_admission_ready": "0",
    "v61gf_generation_acceptance_closure_ready": "0",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61gg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
    "stage_rows": "9",
    "ready_stage_rows": "1",
    "blocked_stage_rows": "8",
    "authority_guard_rows": "2",
    "source_file_rows": "4",
    "payload_like_package_file_rows": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gg {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "real_authority_binding_guard_rows.csv",
    "real_authority_binding_guard_stage_rows.csv",
    "real_authority_binding_guard_source_rows.csv",
    "real_authority_binding_guard_package_file_rows.csv",
    "V61GG_POST_GF_REAL_AUTHORITY_BINDING_GUARD_BOUNDARY.md",
    "v61gg_post_gf_real_authority_binding_guard_manifest.json",
    "v61gg_post_gf_real_authority_binding_guard_summary.csv",
    "v61gg_post_gf_real_authority_binding_guard_decision.csv",
    "real_authority_binding_guard/REAL_AUTHORITY_BINDING_GUARD_ROWS.csv",
    "real_authority_binding_guard/REAL_AUTHORITY_BINDING_GUARD_STAGE_ROWS.csv",
    "real_authority_binding_guard/REAL_AUTHORITY_BINDING_GUARD_MANIFEST.json",
    "real_authority_binding_guard/REAL_AUTHORITY_BINDING_GUARD.md",
    "real_authority_binding_guard/VERIFY_REAL_AUTHORITY_BINDING_GUARD.sh",
    "source_v61gf/v61gf_post_ge_dual_partial_return_replay_admission_summary.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61gg artifact: {rel}")

if not os.access(guard_dir / "VERIFY_REAL_AUTHORITY_BINDING_GUARD.sh", os.X_OK):
    raise SystemExit("v61gg verifier must be executable")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["source-v61gf-ready", "zero-repo-checkpoint-payload"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v61gg expected pass decision: {gate}")
for gate in [
    "v53-authority-binding",
    "v61-authority-binding",
    "dual-authority-binding",
    "v61gf-real-return-replay-admission",
    "authority-bound-replay-admission",
    "actual-generation",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gg expected blocked decision: {gate}")

manifest = json.loads((guard_dir / "REAL_AUTHORITY_BINDING_GUARD_MANIFEST.json").read_text(encoding="utf-8"))
if manifest["summary"].get("authority_bound_replay_admission_ready") != 0:
    raise SystemExit("v61gg default package must keep authority-bound replay blocked")

boundary = (run_dir / "V61GG_POST_GF_REAL_AUTHORITY_BINDING_GUARD_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "v61gg_post_gf_real_authority_binding_guard_ready=1",
    "v53_authority_binding_ready=0",
    "v61_authority_binding_ready=0",
    "dual_authority_binding_ready=0",
    "authority_bound_replay_admission_ready=0",
    "actual_model_generation_ready=0",
    "checkpoint_payload_bytes_committed_to_repo=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61gg boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61gg sha256 mismatch: {rel}")

print("v61gg default no-root authority guard smoke passed")
PY

TMP_ROOT="${TMPDIR:-/tmp}/v61gg_spoof_external_missing_authority_roots"
rm -rf "$TMP_ROOT"

python3 - "$ROOT_DIR" "$TMP_ROOT" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
tmp_root = Path(sys.argv[2])
v53_root = tmp_root / "v53"
v61_root = tmp_root / "v61"
agg = v53_root / "aggregate_review_return"
gen = v61_root / "generation_result_return"
prov = v61_root / "review_return_provenance"
agg.mkdir(parents=True, exist_ok=True)
gen.mkdir(parents=True, exist_ok=True)
prov.mkdir(parents=True, exist_ok=True)
results = root / "results"


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha_file(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


answers = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_answer_packet_rows.csv")
queue = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_queue_rows.csv")
assignments = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "reviewer_assignment_template_rows.csv")
first_queue = next(row for row in queue if row["priority_class"] == "p0_answer_or_policy_mismatch")
answer = next(row for row in answers if row["answer_id"] == first_queue["answer_id"])
assignment = next(row for row in assignments if row["system_id"] == answer["system_id"])
reviewer_id = "spoof_reviewer_v61gg"

human_path = agg / "human_review_rows.csv"
write_csv(human_path, [
    "review_answer_packet_id",
    "answer_id",
    "system_id",
    "query_id",
    "reviewer_id",
    "review_decision",
    "source_support_verified",
    "citation_verified",
    "policy_verified",
    "review_comment_sha256",
], [{
    "review_answer_packet_id": answer["review_answer_packet_id"],
    "answer_id": answer["answer_id"],
    "system_id": answer["system_id"],
    "query_id": answer["query_id"],
    "reviewer_id": reviewer_id,
    "review_decision": "accept",
    "source_support_verified": "1",
    "citation_verified": "1",
    "policy_verified": "1",
    "review_comment_sha256": sha_text("spoof review comment"),
}])

adjudication_path = agg / "adjudication_rows.csv"
write_csv(adjudication_path, [
    "adjudication_id",
    "review_answer_packet_id",
    "answer_id",
    "adjudicator_id",
    "adjudication_decision",
    "adjudication_reason_sha256",
], [{
    "adjudication_id": "spoof_v61gg_adjudication_001",
    "review_answer_packet_id": answer["review_answer_packet_id"],
    "answer_id": answer["answer_id"],
    "adjudicator_id": "spoof_adjudicator_v61gg",
    "adjudication_decision": "accept",
    "adjudication_reason_sha256": sha_text("spoof adjudication reason"),
}])

identity_path = agg / "reviewer_identity_rows.csv"
write_csv(identity_path, [
    "assignment_id",
    "reviewer_id",
    "reviewer_slot_id",
    "system_id",
    "review_scope",
    "independence_declared",
    "credential_statement_sha256",
], [{
    "assignment_id": assignment["assignment_id"],
    "reviewer_id": reviewer_id,
    "reviewer_slot_id": assignment["reviewer_slot_id"],
    "system_id": assignment["system_id"],
    "review_scope": assignment["review_scope"],
    "independence_declared": "1",
    "credential_statement_sha256": sha_text("spoof credential statement"),
}])

conflict_path = agg / "reviewer_conflict_rows.csv"
write_csv(conflict_path, [
    "assignment_id",
    "reviewer_id",
    "owner_repo",
    "conflict_declared",
    "conflict_statement_sha256",
], [{
    "assignment_id": assignment["assignment_id"],
    "reviewer_id": reviewer_id,
    "owner_repo": answer["owner_repo"],
    "conflict_declared": "0",
    "conflict_statement_sha256": sha_text("spoof conflict clear"),
}])

acceptance = {
    "review_protocol_version": "v61gd-partial-v53-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_human_review_rows": 1,
    "human_review_rows_sha256": sha_file(human_path),
    "accepted_adjudication_rows": 1,
    "adjudication_rows_sha256": sha_file(adjudication_path),
    "accepted_reviewer_identity_rows": 1,
    "reviewer_identity_rows_sha256": sha_file(identity_path),
    "accepted_conflict_disclosure_rows": 1,
    "reviewer_conflict_rows_sha256": sha_file(conflict_path),
}
(agg / "acceptance_summary.json").write_text(json.dumps(acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(v53_root / "REAL_EXTERNAL_RETURN_PROVENANCE.json").write_text(json.dumps({
    "provenance": "real-external-return-bundle",
    "source_class": "external-operator-return",
    "reviewer_authority_sha256": sha_text("missing reviewer authority file"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")

query = read_csv(results / "v53r_complete_source_review_packet" / "review_001" / "review_query_packet_rows.csv")[0]
generation_id = "spoof_v61gg_generation_001"
latency_id = "spoof_v61gg_latency_001"
model_id = "mistralai/Mixtral-8x22B-v0.1"
checkpoint_root = "/spoof/checkpoint/root"

answer_gen_path = gen / "real_model_generation_answer_rows.csv"
write_csv(answer_gen_path, [
    "generation_id",
    "review_query_packet_id",
    "query_id",
    "source_span_id",
    "model_id",
    "checkpoint_root",
    "answer_text_sha256",
    "generation_status",
    "abstain_decision",
    "fallback_used",
    "latency_row_id",
    "run_transcript_sha256",
], [{
    "generation_id": generation_id,
    "review_query_packet_id": query["review_query_packet_id"],
    "query_id": query["query_id"],
    "source_span_id": query["source_span_id"],
    "model_id": model_id,
    "checkpoint_root": checkpoint_root,
    "answer_text_sha256": sha_text("spoof generation answer"),
    "generation_status": "generated",
    "abstain_decision": "0",
    "fallback_used": "0",
    "latency_row_id": latency_id,
    "run_transcript_sha256": sha_text("spoof transcript"),
}])

citation_path = gen / "real_model_generation_citation_rows.csv"
write_csv(citation_path, [
    "generation_id",
    "query_id",
    "citation_id",
    "source_span_id",
    "source_file_sha256",
    "citation_verified",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "citation_id": "spoof_v61gg_citation_001",
    "source_span_id": query["source_span_id"],
    "source_file_sha256": query["source_file_sha256"],
    "citation_verified": "1",
}])

abstain_path = gen / "real_model_generation_abstain_fallback_rows.csv"
write_csv(abstain_path, [
    "generation_id",
    "query_id",
    "expected_behavior",
    "abstain_expected",
    "abstain_observed",
    "fallback_used",
    "fallback_reason",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "expected_behavior": query["expected_behavior"],
    "abstain_expected": "0",
    "abstain_observed": "0",
    "fallback_used": "0",
    "fallback_reason": "",
}])

latency_path = gen / "real_model_generation_latency_rows.csv"
write_csv(latency_path, [
    "generation_id",
    "query_id",
    "prompt_tokens",
    "output_tokens",
    "prefill_ms",
    "decode_ms",
    "total_ms",
    "tokens_per_second",
], [{
    "generation_id": generation_id,
    "query_id": query["query_id"],
    "prompt_tokens": "128",
    "output_tokens": "32",
    "prefill_ms": "11.0",
    "decode_ms": "22.0",
    "total_ms": "33.0",
    "tokens_per_second": "969.696969",
}])

generation_acceptance = {
    "generation_protocol_version": "v61ge-partial-generation-slice",
    "acceptance_decision": "accepted-partial-slice",
    "slice_scope": "partial",
    "accepted_answer_rows": 1,
    "answer_rows_sha256": sha_file(answer_gen_path),
    "accepted_citation_rows": 1,
    "citation_rows_sha256": sha_file(citation_path),
    "accepted_abstain_fallback_rows": 1,
    "abstain_fallback_rows_sha256": sha_file(abstain_path),
    "accepted_latency_rows": 1,
    "latency_rows_sha256": sha_file(latency_path),
}
(gen / "real_model_generation_acceptance_summary.json").write_text(json.dumps(generation_acceptance, indent=2, sort_keys=True) + "\n", encoding="utf-8")
(prov / "REAL_REVIEW_RETURN_PROVENANCE.json").write_text(json.dumps({
    "provenance": "real-generation-intake-return-bundle",
    "source_class": "external-generation-intake-return",
    "generation_operator_authority_sha256": sha_text("missing generation authority file"),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

V61GG_RUN_ID="spoof_missing_authority" \
V61GG_V53_RETURN_ROOT="$TMP_ROOT/v53" \
V61GG_V53_RETURN_PROVENANCE="real-external-return-bundle" \
V61GG_V61_RETURN_ROOT="$TMP_ROOT/v61" \
V61GG_V61_RETURN_PROVENANCE="real-generation-intake-return-bundle" \
V61GG_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gg_post_gf_real_authority_binding_guard.sh" >/dev/null

python3 - "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v53_authority_marker_exists": "1",
    "v53_authority_file_exists": "0",
    "v53_authority_binding_ready": "0",
    "v61_authority_marker_exists": "1",
    "v61_authority_file_exists": "0",
    "v61_authority_binding_ready": "0",
    "dual_authority_binding_ready": "0",
    "v61gf_row_acceptance_ready": "1",
    "v61gf_generation_execution_admission_ready": "1",
    "v61gf_dual_external_return_real_ready": "1",
    "v61gf_real_return_replay_admission_ready": "1",
    "v61gf_generation_acceptance_closure_ready": "1",
    "authority_bound_replay_admission_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61gg spoof missing authority {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("v61gf-real-return-replay-admission") != "pass":
    raise SystemExit("v61gg spoof should prove v61gf can open before authority binding")
for gate in ["v53-authority-binding", "v61-authority-binding", "dual-authority-binding", "authority-bound-replay-admission"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v61gg spoof must keep authority gate blocked: {gate}")

print("v61gg spoof missing authority rejection smoke passed")
PY

V61GG_RUN_ID="guard_001" \
V61GG_REUSE_EXISTING=0 \
"$ROOT_DIR/experiments/run_v61gg_post_gf_real_authority_binding_guard.sh" >/dev/null
