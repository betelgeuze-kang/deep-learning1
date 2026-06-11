#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61n_source_bound_qa_workload"
RUN_ID="${V61N_RUN_ID:-qa_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61N_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61n_source_bound_qa_workload_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v61j_one_command_ssd_resident_demo_summary.csv" \
  || ! -s "$RESULTS_DIR/v61j_one_command_ssd_resident_demo/demo_001/runtime_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61j_one_command_ssd_resident_demo.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v61m_kv_cache_residency_eviction_policy_summary.csv" \
  || ! -s "$RESULTS_DIR/v61m_kv_cache_residency_eviction_policy/kv_001/kv_residency_policy_rows.csv" ]]; then
  "$ROOT_DIR/experiments/run_v61m_kv_cache_residency_eviction_policy.sh" >/dev/null
fi
if [[ ! -s "$RESULTS_DIR/v53g_complete_source_manifest_summary.csv" \
  || ! -s "$RESULTS_DIR/v53g_complete_source_manifest/manifest_001/complete_source_file_manifest_rows.csv" ]]; then
  "$ROOT_DIR/experiments/run_v53g_complete_source_manifest.sh" >/dev/null
fi

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
v61j_dir = results / "v61j_one_command_ssd_resident_demo" / "demo_001"
v61m_dir = results / "v61m_kv_cache_residency_eviction_policy" / "kv_001"
v53g_dir = results / "v53g_complete_source_manifest" / "manifest_001"
v53c_dir = results / "v53c_public_repo_canary_source_snapshot" / "snapshot_001"


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


def first_nonempty_line(text):
    for idx, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped:
            return idx, stripped[:240]
    return 1, ""


def source_category(path):
    lower = path.lower()
    name = lower.rsplit("/", 1)[-1]
    if lower.startswith(("tests/", "test/")) or "/tests/" in lower or "/test/" in lower:
        return "test"
    if lower.endswith((".py", ".pyi")):
        return "source"
    if name in {"pyproject.toml", "tox.ini"} or lower.endswith((".toml", ".ini", ".yaml", ".yml", ".cfg")):
        return "config"
    if lower.startswith(("docs/", "doc/", "readme")) or "/docs/" in lower or "/doc/" in lower or lower.endswith((".md", ".rst", ".txt")):
        return "doc"
    return "other"


v61j_summary = read_csv(results / "v61j_one_command_ssd_resident_demo_summary.csv")[0]
v61m_summary = read_csv(results / "v61m_kv_cache_residency_eviction_policy_summary.csv")[0]
v53g_summary = read_csv(results / "v53g_complete_source_manifest_summary.csv")[0]
if v61j_summary.get("v61j_one_command_ssd_resident_demo_ready") != "1":
    raise SystemExit("v61n requires v61j_one_command_ssd_resident_demo_ready=1")
if v61m_summary.get("v61m_kv_cache_residency_eviction_policy_ready") != "1":
    raise SystemExit("v61n requires v61m_kv_cache_residency_eviction_policy_ready=1")
if v53g_summary.get("v53g_complete_source_manifest_ready") != "1":
    raise SystemExit("v61n requires v53g_complete_source_manifest_ready=1")

for rel in [
    "runtime_summary.csv",
    "routehint_schedule_trace.csv",
    "ssd_vram_budget_report.csv",
    "V61J_ONE_COMMAND_SSD_RESIDENT_DEMO_BOUNDARY.md",
    "v61j_one_command_ssd_resident_demo_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61j_dir / rel, f"source_v61j/{rel}")
copy(results / "v61j_one_command_ssd_resident_demo_summary.csv", "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv")

for rel in [
    "kv_cache_geometry_rows.csv",
    "kv_residency_policy_rows.csv",
    "kv_budget_profile_rows.csv",
    "kv_eviction_trace_rows.csv",
    "V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md",
    "v61m_kv_cache_residency_eviction_policy_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v61m_dir / rel, f"source_v61m/{rel}")
copy(results / "v61m_kv_cache_residency_eviction_policy_summary.csv", "source_v61m/v61m_kv_cache_residency_eviction_policy_summary.csv")

for rel in [
    "complete_source_file_manifest_rows.csv",
    "complete_source_repo_coverage_rows.csv",
    "complete_source_query_budget_rows.csv",
    "complete_source_gap_rows.csv",
    "V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "v53g_complete_source_manifest_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53g_dir / rel, f"source_v53g/{rel}")
copy(results / "v53g_complete_source_manifest_summary.csv", "source_v53g/v53g_complete_source_manifest_summary.csv")

for rel in [
    "public_repo_canary_source_snapshot_rows.csv",
    "V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "v53c_public_repo_canary_source_snapshot_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v53c_dir / rel, f"source_v53c/{rel}")
copy(results / "v53c_public_repo_canary_source_snapshot_summary.csv", "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv")

file_manifest = read_csv(v53g_dir / "complete_source_file_manifest_rows.csv")
manifest_by_key = {(row["owner_repo"], row["path"]): row for row in file_manifest}
canary_rows = read_csv(v53c_dir / "public_repo_canary_source_snapshot_rows.csv")
eligible_canary_rows = []
for row in canary_rows:
    key = (row["owner_repo"], row["path"])
    manifest_row = manifest_by_key.get(key)
    if not manifest_row or manifest_row.get("canary_overlap") != "1":
        continue
    source_path = v53c_dir / row["local_relpath"]
    if not source_path.is_file():
        continue
    if sha256(source_path) != row["content_sha256"]:
        raise SystemExit(f"v61n source hash mismatch for {row['owner_repo']}:{row['path']}")
    eligible_canary_rows.append((row, manifest_row, source_path))

if len(eligible_canary_rows) < 20:
    raise SystemExit(f"v61n requires at least 20 canary-overlap source files, got {len(eligible_canary_rows)}")

binding_rows = []
query_rows = []
answer_rows = []
citation_rows = []
resource_rows = []
abstain_rows = []
source_rels = []

for idx, (row, manifest_row, source_path) in enumerate(eligible_canary_rows, start=1):
    copied_rel = f"source_v53c/{row['local_relpath']}"
    copy(source_path, copied_rel)
    source_rels.append(copied_rel)
    content = source_path.read_text(encoding="utf-8", errors="replace")
    line_no, excerpt = first_nonempty_line(content)
    category = source_category(row["path"])
    workload_id = f"v61n_supported_{idx:03d}"
    binding_rows.append(
        {
            "workload_id": workload_id,
            "owner_repo": row["owner_repo"],
            "path": row["path"],
            "head_sha": row["head_sha"],
            "git_blob_sha": row["git_blob_sha"],
            "v53g_manifest_canary_overlap": manifest_row["canary_overlap"],
            "v53g_content_materialized": manifest_row["content_materialized"],
            "v53c_content_materialized": "1",
            "content_sha256": row["content_sha256"],
            "source_category": category,
            "local_source_copy": copied_rel,
        }
    )
    query_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "owner_repo": row["owner_repo"],
            "path": row["path"],
            "query_family": "source_line_identity",
            "question": f"What is the first non-empty line in pinned source file {row['owner_repo']}:{row['path']}?",
            "expected_source_category": category,
            "requires_abstain": "0",
            "source_bound": "1",
        }
    )
    answer_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "answer_status": "answered",
            "answer_text": f"First non-empty line {line_no}: {excerpt}",
            "answer_supported_by_citation": "1",
            "abstained": "0",
            "unsupported_claim": "0",
            "source_bound_answer_ready": "1",
        }
    )
    citation_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "citation_id": f"cite_{workload_id}",
            "owner_repo": row["owner_repo"],
            "path": row["path"],
            "line_start": str(line_no),
            "line_end": str(line_no),
            "content_sha256": row["content_sha256"],
            "cited_excerpt": excerpt,
            "citation_supports_answer": "1",
            "citation_kind": "materialized-canary-source",
        }
    )
    resource_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "runtime_path": "v61j-one-command-bound",
            "kv_policy": "v61m_mixtral_kv_vram_hot_nvme_cold_001",
            "source_bytes_read": row["bytes"],
            "source_line_count": row["line_count"],
            "real_checkpoint_weight_bytes_materialized": "0",
            "host_ram_kv_spill_bytes": "0",
            "near_frontier_claim_ready": "0",
            "production_latency_claim_ready": "0",
        }
    )

repo_first = {}
for row, manifest_row, source_path in eligible_canary_rows:
    repo_first.setdefault(row["owner_repo"], (row, manifest_row, source_path))

for idx, owner_repo in enumerate(sorted(repo_first), start=1):
    row, manifest_row, source_path = repo_first[owner_repo]
    workload_id = f"v61n_abstain_{idx:03d}"
    question = f"Do the pinned source rows for {owner_repo} prove near-frontier local 100B inference quality?"
    answer_text = "Abstain: these source-bound rows verify pinned source citations and runtime binding only; they do not prove near-frontier local inference quality."
    query_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "owner_repo": owner_repo,
            "path": row["path"],
            "query_family": "unsupported_runtime_claim_abstain",
            "question": question,
            "expected_source_category": "boundary",
            "requires_abstain": "1",
            "source_bound": "1",
        }
    )
    answer_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "answer_status": "abstained",
            "answer_text": answer_text,
            "answer_supported_by_citation": "1",
            "abstained": "1",
            "unsupported_claim": "1",
            "source_bound_answer_ready": "1",
        }
    )
    abstain_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "abstain_reason": "unsupported-near-frontier-runtime-claim",
            "required_evidence_missing": "real-checkpoint-materialization;source-bound-model-generation;quality-review",
            "abstain_policy_verified": "1",
        }
    )
    citation_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "citation_id": f"cite_{workload_id}",
            "owner_repo": owner_repo,
            "path": "source_v61m/V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md",
            "line_start": "",
            "line_end": "",
            "content_sha256": sha256(run_dir / "source_v61m/V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md"),
            "cited_excerpt": "Blocked wording: source-bound QA runtime, exact long-context quality, production latency, near-frontier local inference, or release readiness.",
            "citation_supports_answer": "1",
            "citation_kind": "runtime-boundary",
        }
    )
    resource_rows.append(
        {
            "workload_id": workload_id,
            "query_id": workload_id,
            "runtime_path": "v61j-one-command-bound",
            "kv_policy": "v61m_mixtral_kv_vram_hot_nvme_cold_001",
            "source_bytes_read": "0",
            "source_line_count": "0",
            "real_checkpoint_weight_bytes_materialized": "0",
            "host_ram_kv_spill_bytes": "0",
            "near_frontier_claim_ready": "0",
            "production_latency_claim_ready": "0",
        }
    )

runtime_binding_rows = [
    {
        "binding_id": "v61n_runtime_binding_001",
        "one_command_entrypoint": "./examples/v61_ssd_resident_moe_demo.sh",
        "v61j_one_command_ssd_resident_demo_ready": v61j_summary["v61j_one_command_ssd_resident_demo_ready"],
        "v61m_kv_cache_residency_eviction_policy_ready": v61m_summary["v61m_kv_cache_residency_eviction_policy_ready"],
        "v53g_complete_source_manifest_ready": v53g_summary["v53g_complete_source_manifest_ready"],
        "source_bound_workload_rows": str(len(query_rows)),
        "runtime_binding_ready": "1",
        "actual_model_generation_ready": "0",
        "real_checkpoint_weight_bytes_materialized": "0",
    }
]

gap_rows = [
    ("complete-source-content-materialization", "blocked", "v61n uses the materialized v53c canary-overlap subset; full v53g content materialization is still absent"),
    ("complete-source-1000-query-workload", "blocked", "v61n emits a 40-row source-bound seed, not the 1000+ complete-source v53 audit"),
    ("source-bound-model-generation", "blocked", "answers are deterministic source-bound citation rows, not real Mixtral checkpoint generation"),
    ("safetensors-page-hash-binding", "blocked", "real safetensors page hashes are not bound to kernel inputs"),
    ("near-frontier-quality", "blocked", "near-frontier quality is not proven by this workload seed"),
    ("production-latency", "blocked", "resource rows are not production decode latency evidence"),
    ("release-package", "blocked", "not a release package"),
]

write_csv(run_dir / "source_manifest_binding_rows.csv", list(binding_rows[0].keys()), binding_rows)
write_csv(run_dir / "source_bound_query_rows.csv", list(query_rows[0].keys()), query_rows)
write_csv(run_dir / "source_bound_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
write_csv(run_dir / "source_bound_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
write_csv(run_dir / "source_bound_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
write_csv(run_dir / "source_bound_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
write_csv(run_dir / "runtime_binding_rows.csv", list(runtime_binding_rows[0].keys()), runtime_binding_rows)
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": status, "reason": reason} for gap, status, reason in gap_rows],
)

category_counts = Counter(row["expected_source_category"] for row in query_rows if row["requires_abstain"] == "0")
supported_rows = sum(1 for row in answer_rows if row["answer_status"] == "answered")
abstained_rows = sum(1 for row in answer_rows if row["answer_status"] == "abstained")
summary = {
    "v61n_source_bound_qa_workload_ready": "1",
    "v61j_one_command_ssd_resident_demo_ready": v61j_summary["v61j_one_command_ssd_resident_demo_ready"],
    "v61m_kv_cache_residency_eviction_policy_ready": v61m_summary["v61m_kv_cache_residency_eviction_policy_ready"],
    "v53g_complete_source_manifest_ready": v53g_summary["v53g_complete_source_manifest_ready"],
    "v53c_materialized_canary_source_ready": "1",
    "source_bound_qa_workload_ready": "1",
    "source_bound_qa_ready": "1",
    "source_bound_query_rows": str(len(query_rows)),
    "source_bound_supported_answer_rows": str(supported_rows),
    "source_bound_abstain_rows": str(abstained_rows),
    "source_bound_citation_rows": str(len(citation_rows)),
    "source_bound_resource_rows": str(len(resource_rows)),
    "bound_repo_count": str(len(repo_first)),
    "materialized_source_file_rows": str(len(eligible_canary_rows)),
    "complete_source_manifest_binding_rows": str(len(binding_rows)),
    "source_category_source_rows": str(category_counts.get("source", 0)),
    "source_category_doc_rows": str(category_counts.get("doc", 0)),
    "source_category_config_rows": str(category_counts.get("config", 0)),
    "source_category_test_rows": str(category_counts.get("test", 0)),
    "answer_citation_support_pass_rows": str(sum(1 for row in answer_rows if row["answer_supported_by_citation"] == "1")),
    "abstain_policy_verified_rows": str(len(abstain_rows)),
    "runtime_binding_ready": "1",
    "actual_model_generation_ready": "0",
    "complete_source_1000_query_ready": "0",
    "complete_source_content_snapshot_ready": "0",
    "real_checkpoint_weight_bytes_materialized": "0",
    "real_100b_open_weight_materialized": "0",
    "safetensors_page_hash_binding_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v61j-one-command-input", "pass", "v61j one-command SSD-resident demo is bound"),
    ("v61m-kv-policy-input", "pass", "v61m KV residency/eviction policy is bound"),
    ("v53g-complete-source-manifest-input", "pass", "v53g complete-source manifest is bound"),
    ("materialized-canary-source-overlap", "pass", f"materialized_source_file_rows={len(eligible_canary_rows)}"),
    ("source-bound-qa-workload-seed", "pass", f"source_bound_query_rows={len(query_rows)}"),
    ("citation-support", "pass", f"source_bound_citation_rows={len(citation_rows)}"),
    ("abstain-policy", "pass", f"source_bound_abstain_rows={abstained_rows}"),
    ("complete-source-1000-query-workload", "blocked", "v61n is a 40-row seed, not the full v53 1000+ complete-source audit"),
    ("source-bound-model-generation", "blocked", "real Mixtral checkpoint generation is not materialized"),
    ("safetensors-page-hash-binding", "blocked", "real safetensors page hashes are not bound"),
    ("near-frontier-quality", "blocked", "not a near-frontier quality evaluation"),
    ("production-latency", "blocked", "not a production latency benchmark"),
    ("release-package", "blocked", "not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

(run_dir / "V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md").write_text(
    "# v61n Source-Bound QA Workload Boundary\n\n"
    "This layer binds the v61j one-command SSD-resident runtime evidence, the v61m KV policy, and the v53g complete-source manifest to a source-bound QA workload seed. "
    "Supported answers are generated only from materialized v53c canary-overlap files that are also present in the v53g complete-source manifest. Unsupported near-frontier/runtime claims abstain.\n\n"
    f"- source_bound_query_rows={len(query_rows)}\n"
    f"- source_bound_supported_answer_rows={supported_rows}\n"
    f"- source_bound_abstain_rows={abstained_rows}\n"
    f"- materialized_source_file_rows={len(eligible_canary_rows)}\n"
    f"- bound_repo_count={len(repo_first)}\n"
    "- source_bound_qa_workload_ready=1\n"
    "- actual_model_generation_ready=0\n"
    "- complete_source_1000_query_ready=0\n"
    "- complete_source_content_snapshot_ready=0\n"
    "- real_checkpoint_weight_bytes_materialized=0\n"
    "- safetensors_page_hash_binding_ready=0\n"
    "- near_frontier_claim_ready=0\n"
    "- production_latency_claim_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed wording: source-bound QA workload seed over materialized canary-overlap files, bound to the v61 runtime evidence chain and v53g complete-source manifest. "
    "Blocked wording: complete-source 1000+ audit completion, real Mixtral generation, near-frontier local inference, production latency, or release readiness.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v61n-source-bound-qa-workload",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61n_source_bound_qa_workload_ready": 1,
    "v61j_summary_sha256": sha256(results / "v61j_one_command_ssd_resident_demo_summary.csv"),
    "v61m_summary_sha256": sha256(results / "v61m_kv_cache_residency_eviction_policy_summary.csv"),
    "v53g_summary_sha256": sha256(results / "v53g_complete_source_manifest_summary.csv"),
    "source_bound_query_rows": len(query_rows),
    "source_bound_supported_answer_rows": supported_rows,
    "source_bound_abstain_rows": abstained_rows,
    "materialized_source_file_rows": len(eligible_canary_rows),
    "bound_repo_count": len(repo_first),
    "actual_model_generation_ready": 0,
    "complete_source_1000_query_ready": 0,
    "real_checkpoint_weight_bytes_materialized": 0,
    "near_frontier_claim_ready": 0,
    "production_latency_claim_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v61n_source_bound_qa_workload_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

artifact_rels = [
    "source_manifest_binding_rows.csv",
    "source_bound_query_rows.csv",
    "source_bound_answer_rows.csv",
    "source_bound_citation_rows.csv",
    "source_bound_abstain_rows.csv",
    "source_bound_resource_rows.csv",
    "runtime_binding_rows.csv",
    "runtime_gap_rows.csv",
    "V61N_SOURCE_BOUND_QA_WORKLOAD_BOUNDARY.md",
    "v61n_source_bound_qa_workload_manifest.json",
    "source_v61j/runtime_summary.csv",
    "source_v61j/routehint_schedule_trace.csv",
    "source_v61j/ssd_vram_budget_report.csv",
    "source_v61j/V61J_ONE_COMMAND_SSD_RESIDENT_DEMO_BOUNDARY.md",
    "source_v61j/v61j_one_command_ssd_resident_demo_manifest.json",
    "source_v61j/sha256_manifest.csv",
    "source_v61j/v61j_one_command_ssd_resident_demo_summary.csv",
    "source_v61m/kv_cache_geometry_rows.csv",
    "source_v61m/kv_residency_policy_rows.csv",
    "source_v61m/kv_budget_profile_rows.csv",
    "source_v61m/kv_eviction_trace_rows.csv",
    "source_v61m/V61M_KV_CACHE_RESIDENCY_EVICTION_BOUNDARY.md",
    "source_v61m/v61m_kv_cache_residency_eviction_policy_manifest.json",
    "source_v61m/sha256_manifest.csv",
    "source_v61m/v61m_kv_cache_residency_eviction_policy_summary.csv",
    "source_v53g/complete_source_file_manifest_rows.csv",
    "source_v53g/complete_source_repo_coverage_rows.csv",
    "source_v53g/complete_source_query_budget_rows.csv",
    "source_v53g/complete_source_gap_rows.csv",
    "source_v53g/V53G_COMPLETE_SOURCE_MANIFEST_BOUNDARY.md",
    "source_v53g/v53g_complete_source_manifest_manifest.json",
    "source_v53g/sha256_manifest.csv",
    "source_v53g/v53g_complete_source_manifest_summary.csv",
    "source_v53c/public_repo_canary_source_snapshot_rows.csv",
    "source_v53c/V53C_PUBLIC_REPO_CANARY_SOURCE_SNAPSHOT_BOUNDARY.md",
    "source_v53c/v53c_public_repo_canary_source_snapshot_manifest.json",
    "source_v53c/sha256_manifest.csv",
    "source_v53c/v53c_public_repo_canary_source_snapshot_summary.csv",
]
artifact_rels.extend(source_rels)
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v61n_source_bound_qa_workload_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
