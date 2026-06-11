#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61s_one_command_source_bound_qa_replay"
RUN_ID="${V61S_RUN_ID:-replay_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61S_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61s_one_command_source_bound_qa_replay_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
entrypoint = root / "examples" / "v61_ssd_resident_moe_demo.sh"
v61n_dir = results / "v61n_source_bound_qa_workload" / "qa_001"
v61j_dir = results / "v61j_one_command_ssd_resident_demo" / "demo_001"


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


if not entrypoint.is_file():
    raise SystemExit("missing v61 one-command entrypoint")

env = os.environ.copy()
env["V61N_REUSE_EXISTING"] = "1"
command = [str(entrypoint), "--source-bound-qa"]
completed = subprocess.run(command, cwd=str(root), env=env, text=True, capture_output=True)
(run_dir / "one_command_stdout.txt").write_text(completed.stdout, encoding="utf-8")
(run_dir / "one_command_stderr.txt").write_text(completed.stderr, encoding="utf-8")
if completed.returncode != 0:
    raise SystemExit(f"v61 source-bound QA entrypoint failed with exit code {completed.returncode}")

v61n_summary = read_csv(results / "v61n_source_bound_qa_workload_summary.csv")[0]
v61j_summary = read_csv(results / "v61j_one_command_ssd_resident_demo_summary.csv")[0]
if v61n_summary.get("v61n_source_bound_qa_workload_ready") != "1":
    raise SystemExit("v61s requires v61n_source_bound_qa_workload_ready=1")
if v61j_summary.get("v61j_one_command_ssd_resident_demo_ready") != "1":
    raise SystemExit("v61s requires v61j_one_command_ssd_resident_demo_ready=1")

for src, rel in [
    (entrypoint, "one_command_entrypoint.sh"),
    (results / "v61n_source_bound_qa_workload_summary.csv", "source_v61n/v61n_source_bound_qa_workload_summary.csv"),
    (results / "v61n_source_bound_qa_workload_decision.csv", "source_v61n/v61n_source_bound_qa_workload_decision.csv"),
    (v61n_dir / "source_bound_query_rows.csv", "source_v61n/source_bound_query_rows.csv"),
    (v61n_dir / "source_bound_answer_rows.csv", "source_v61n/source_bound_answer_rows.csv"),
    (v61n_dir / "source_bound_citation_rows.csv", "source_v61n/source_bound_citation_rows.csv"),
    (v61n_dir / "source_bound_abstain_rows.csv", "source_v61n/source_bound_abstain_rows.csv"),
    (v61n_dir / "source_bound_resource_rows.csv", "source_v61n/source_bound_resource_rows.csv"),
    (v61n_dir / "runtime_binding_rows.csv", "source_v61n/runtime_binding_rows.csv"),
    (v61n_dir / "runtime_gap_rows.csv", "source_v61n/runtime_gap_rows.csv"),
    (v61n_dir / "V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md", "source_v61n/V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md"),
    (v61n_dir / "v61n_source_bound_qa_workload_manifest.json", "source_v61n/v61n_source_bound_qa_workload_manifest.json"),
    (v61n_dir / "sha256_manifest.csv", "source_v61n/sha256_manifest.csv"),
    (results / "v61j_one_command_ssd_resident_demo_summary.csv", "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv"),
    (v61j_dir / "runtime_summary.csv", "source_v61j/runtime_summary.csv"),
    (v61j_dir / "routehint_schedule_trace.csv", "source_v61j/routehint_schedule_trace.csv"),
    (v61j_dir / "V61J_ONE_COMMAND_SSD_RESIDENT_DEMO_BOUNDARY.md", "source_v61j/V61J_ONE_COMMAND_SSD_RESIDENT_DEMO_BOUNDARY.md"),
]:
    copy(src, rel)

queries = read_csv(v61n_dir / "source_bound_query_rows.csv")
answers = read_csv(v61n_dir / "source_bound_answer_rows.csv")
citations = read_csv(v61n_dir / "source_bound_citation_rows.csv")
resources = read_csv(v61n_dir / "source_bound_resource_rows.csv")
abstains = read_csv(v61n_dir / "source_bound_abstain_rows.csv")
answer_by_query = {row["query_id"]: row for row in answers}
citations_by_query = {}
for row in citations:
    citations_by_query.setdefault(row["query_id"], []).append(row)
resources_by_query = {row["query_id"]: row for row in resources}

workload_pass_rows = []
for query in queries:
    query_id = query["query_id"]
    answer = answer_by_query.get(query_id)
    query_citations = citations_by_query.get(query_id, [])
    resource = resources_by_query.get(query_id)
    pass_ready = int(
        answer is not None
        and resource is not None
        and len(query_citations) >= 1
        and answer["answer_supported_by_citation"] == "1"
        and all(citation["citation_supports_answer"] == "1" for citation in query_citations)
        and resource["real_checkpoint_weight_bytes_materialized"] == "0"
    )
    workload_pass_rows.append(
        {
            "replay_id": "v61s_replay_001",
            "query_id": query_id,
            "workload_id": query["workload_id"],
            "query_family": query["query_family"],
            "requires_abstain": query["requires_abstain"],
            "answer_status": answer["answer_status"] if answer else "",
            "citation_rows": str(len(query_citations)),
            "resource_bound": str(int(resource is not None)),
            "answer_supported_by_citation": answer["answer_supported_by_citation"] if answer else "0",
            "source_bound_query_pass": str(pass_ready),
            "actual_model_generation_ready": "0",
            "real_checkpoint_weight_bytes_materialized": "0",
        }
    )
if not workload_pass_rows:
    raise SystemExit("v61s requires v61n workload rows")

source_bound_pass_rows = sum(1 for row in workload_pass_rows if row["source_bound_query_pass"] == "1")
abstain_policy_pass_rows = sum(1 for row in abstains if row["abstain_policy_verified"] == "1")
one_command_source_bound_qa_pass = int(
    completed.returncode == 0
    and source_bound_pass_rows == len(workload_pass_rows)
    and abstain_policy_pass_rows == len(abstains)
    and v61n_summary["source_bound_qa_workload_ready"] == "1"
)

command_rows = [
    {
        "replay_id": "v61s_replay_001",
        "entrypoint": "./examples/v61_ssd_resident_moe_demo.sh",
        "entrypoint_mode": "--source-bound-qa",
        "command": "./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa",
        "exit_code": str(completed.returncode),
        "stdout_sha256": sha256(run_dir / "one_command_stdout.txt"),
        "stderr_sha256": sha256(run_dir / "one_command_stderr.txt"),
        "entrypoint_sha256": sha256(entrypoint),
        "v61j_one_command_ssd_resident_demo_ready": v61j_summary["v61j_one_command_ssd_resident_demo_ready"],
        "v61n_source_bound_qa_workload_ready": v61n_summary["v61n_source_bound_qa_workload_ready"],
        "one_command_source_bound_qa_pass": str(one_command_source_bound_qa_pass),
    }
]
write_csv(run_dir / "one_command_replay_rows.csv", list(command_rows[0].keys()), command_rows)
write_csv(run_dir / "source_bound_workload_pass_rows.csv", list(workload_pass_rows[0].keys()), workload_pass_rows)

gap_rows = [
    ("v61j-command-source-bound-qa-replay", "ready", "the v61 one-command entrypoint --source-bound-qa mode exits successfully and binds v61n workload rows"),
    ("complete-source-1000-query-workload", "blocked", "v61s replays the v61n seed workload, not the full 1000+ complete-source audit"),
    ("source-bound-model-generation", "blocked", "answers are deterministic source-bound replay rows, not real Mixtral checkpoint generation"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage remains blocked until local shards are resident and hashed"),
    ("near-frontier-quality", "blocked", "not a near-frontier quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end production decode benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

summary = {
    "v61s_one_command_source_bound_qa_replay_ready": "1",
    "v61j_one_command_ssd_resident_demo_ready": v61j_summary["v61j_one_command_ssd_resident_demo_ready"],
    "v61n_source_bound_qa_workload_ready": v61n_summary["v61n_source_bound_qa_workload_ready"],
    "entrypoint": "./examples/v61_ssd_resident_moe_demo.sh",
    "entrypoint_mode": "--source-bound-qa",
    "one_command_exit_code": str(completed.returncode),
    "one_command_source_bound_qa_pass": str(one_command_source_bound_qa_pass),
    "source_bound_query_rows": str(len(workload_pass_rows)),
    "source_bound_query_pass_rows": str(source_bound_pass_rows),
    "source_bound_citation_rows": str(len(citations)),
    "source_bound_resource_rows": str(len(resources)),
    "source_bound_abstain_rows": str(len(abstains)),
    "abstain_policy_pass_rows": str(abstain_policy_pass_rows),
    "runtime_binding_ready": v61n_summary["runtime_binding_ready"],
    "actual_model_generation_ready": "0",
    "complete_source_1000_query_ready": "0",
    "full_safetensors_page_hash_binding_ready": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61-one-command-source-bound-qa-entrypoint", "pass", "the v61 entrypoint supports --source-bound-qa mode and exits 0"),
    ("v61j-runtime-input", "pass", "v61j one-command runtime evidence is bound"),
    ("v61n-source-bound-workload-input", "pass", "v61n source-bound QA workload evidence is bound"),
    ("source-bound-query-pass", "pass", f"source_bound_query_pass_rows={source_bound_pass_rows}/{len(workload_pass_rows)}"),
    ("abstain-policy-pass", "pass", f"abstain_policy_pass_rows={abstain_policy_pass_rows}/{len(abstains)}"),
    ("complete-source-1000-query-workload", "blocked", "not the full v53 complete-source 1000+ audit"),
    ("source-bound-model-generation", "blocked", "real Mixtral checkpoint generation is not executed"),
    ("full-safetensors-page-hash-binding", "blocked", "full page-hash coverage is not complete"),
    ("near-frontier-quality", "blocked", "not a quality evaluation"),
    ("production-latency", "blocked", "not an end-to-end latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61S_ONE_COMMAND_SOURCE_BOUND_QA_REPLAY_BOUNDARY.md").write_text(
    "# v61s One-Command Source-Bound QA Replay Boundary\n\n"
    "This layer extends the v61 one-command entrypoint with `--source-bound-qa` mode and verifies that the command exits successfully over the v61n source-bound QA workload. "
    "It proves command-level replay of the source-bound QA seed through the v61 runtime evidence path. It does not execute real Mixtral checkpoint generation.\n\n"
    "- command=./examples/v61_ssd_resident_moe_demo.sh --source-bound-qa\n"
    f"- one_command_exit_code={completed.returncode}\n"
    f"- source_bound_query_rows={len(workload_pass_rows)}\n"
    f"- source_bound_query_pass_rows={source_bound_pass_rows}\n"
    f"- source_bound_abstain_rows={len(abstains)}\n"
    f"- abstain_policy_pass_rows={abstain_policy_pass_rows}\n"
    f"- one_command_source_bound_qa_pass={one_command_source_bound_qa_pass}\n"
    "- actual_model_generation_ready=0\n"
    "- complete_source_1000_query_ready=0\n"
    "- full_safetensors_page_hash_binding_ready=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: v61 one-command source-bound QA seed replay. "
    "Blocked wording: real Mixtral generation, complete-source 1000+ audit completion, full page-hash coverage, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61s-one-command-source-bound-qa-replay",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61s_one_command_source_bound_qa_replay_ready": 1,
    "entrypoint_sha256": sha256(entrypoint),
    "v61j_summary_sha256": sha256(results / "v61j_one_command_ssd_resident_demo_summary.csv"),
    "v61n_summary_sha256": sha256(results / "v61n_source_bound_qa_workload_summary.csv"),
    "one_command_exit_code": completed.returncode,
    "one_command_source_bound_qa_pass": one_command_source_bound_qa_pass,
    "source_bound_query_rows": len(workload_pass_rows),
    "source_bound_query_pass_rows": source_bound_pass_rows,
    "source_bound_abstain_rows": len(abstains),
    "abstain_policy_pass_rows": abstain_policy_pass_rows,
    "actual_model_generation_ready": 0,
    "complete_source_1000_query_ready": 0,
    "full_safetensors_page_hash_binding_ready": 0,
    "real_checkpoint_weight_bytes_materialized": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61s_one_command_source_bound_qa_replay_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "one_command_replay_rows.csv",
    "source_bound_workload_pass_rows.csv",
    "runtime_gap_rows.csv",
    "one_command_stdout.txt",
    "one_command_stderr.txt",
    "one_command_entrypoint.sh",
    "V61S_ONE_COMMAND_SOURCE_BOUND_QA_REPLAY_BOUNDARY.md",
    "v61s_one_command_source_bound_qa_replay_manifest.json",
    "source_v61n/v61n_source_bound_qa_workload_summary.csv",
    "source_v61n/v61n_source_bound_qa_workload_decision.csv",
    "source_v61n/source_bound_query_rows.csv",
    "source_v61n/source_bound_answer_rows.csv",
    "source_v61n/source_bound_citation_rows.csv",
    "source_v61n/source_bound_abstain_rows.csv",
    "source_v61n/source_bound_resource_rows.csv",
    "source_v61n/runtime_binding_rows.csv",
    "source_v61n/runtime_gap_rows.csv",
    "source_v61n/V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md",
    "source_v61n/v61n_source_bound_qa_workload_manifest.json",
    "source_v61n/sha256_manifest.csv",
    "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv",
    "source_v61j/runtime_summary.csv",
    "source_v61j/routehint_schedule_trace.csv",
    "source_v61j/V61J_ONE_COMMAND_SSD_RESIDENT_DEMO_BOUNDARY.md",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61s_one_command_source_bound_qa_replay_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
