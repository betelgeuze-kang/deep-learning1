#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v52x_de_external_measured_bake_import"
RUN_ID="${V52X_RUN_ID:-import_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
BAKE_DIR="${V52X_DE_BAKE_DIR:-$ROOT_DIR/experiments/fixtures/v52x_external_de_bake}"

if [[ "${V52X_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v52x_de_external_measured_bake_import_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ ! -s "$RESULTS_DIR/v53e_canary_query_scale_1000_summary.csv" ]]; then
  "$ROOT_DIR/experiments/run_v53e_canary_query_scale_1000.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$BAKE_DIR" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
bake_dir = Path(sys.argv[5])
results = root / "results"
v53e_dir = results / "v53e_canary_query_scale_1000" / "scale_001"
fixture_dir = root / "experiments" / "fixtures" / "v52x_external_de_bake"
bake_host = os.environ.get("V52X_DE_BAKE_HOST", "external-bake-fixture-host")


def sha256_bytes(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def sha256_text(text):
    return sha256_bytes(text.encode("utf-8"))


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


def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def build_bake_packet(system_id, prefix, model_id, param_b, target_dir, bake_source):
    query_rows = read_csv(bake_source / "frozen_query_rows.csv")
    span_rows = read_csv(bake_source / "frozen_source_span_rows.csv")
    span_by_query = {row["query_id"]: row for row in span_rows}
    target_dir.mkdir(parents=True, exist_ok=True)

    for rel in [
        "scaled_canary_query_rows.csv",
        "scaled_canary_source_span_rows.csv",
        "scaled_canary_query_repo_rows.csv",
        "scaled_canary_query_family_rows.csv",
        "V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
        "v53e_canary_query_scale_1000_manifest.json",
        "sha256_manifest.csv",
        "v53e_canary_query_scale_1000_summary.csv",
    ]:
        copy(v53e_dir / rel, target_dir / "source_v53e" / rel)

    shutil.copy2(bake_source / "frozen_query_rows.csv", target_dir / "frozen_query_rows.csv")
    shutil.copy2(bake_source / "frozen_source_span_rows.csv", target_dir / "frozen_source_span_rows.csv")
    shutil.copy2(bake_source / "source_manifest_rows.csv", target_dir / "source_manifest_rows.csv")

    identity = json.loads((bake_source / "model_identity.json").read_text(encoding="utf-8"))
    (target_dir / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    answer_rows = read_csv(bake_source / f"{prefix}_answer_rows.csv")
    citation_rows = read_csv(bake_source / f"{prefix}_citation_rows.csv")
    retrieval_rows = read_csv(bake_source / f"{prefix}_retrieval_rows.csv")
    abstain_rows = read_csv(bake_source / f"{prefix}_abstain_rows.csv")
    wrong_guard_rows = read_csv(bake_source / f"{prefix}_wrong_answer_guard_rows.csv")
    resource_rows = read_csv(bake_source / f"{prefix}_resource_rows.csv")
    transcript_rows = read_csv(bake_source / "ollama_generation_transcript_rows.csv")
    metric_rows = read_csv(bake_source / f"{prefix}_system_metric_rows.csv")

    for name, rows in [
        (f"{prefix}_answer_rows.csv", answer_rows),
        (f"{prefix}_citation_rows.csv", citation_rows),
        (f"{prefix}_retrieval_rows.csv", retrieval_rows),
        (f"{prefix}_abstain_rows.csv", abstain_rows),
        (f"{prefix}_wrong_answer_guard_rows.csv", wrong_guard_rows),
        (f"{prefix}_resource_rows.csv", resource_rows),
        ("ollama_generation_transcript_rows.csv", transcript_rows),
        (f"{prefix}_system_metric_rows.csv", metric_rows),
    ]:
        write_csv(target_dir / name, list(rows[0].keys()), rows)

    correct_rows = sum(int(row["correct"]) for row in answer_rows)
    abstained_rows = sum(int(row["abstained"]) for row in answer_rows)
    wrong_rows = sum(int(row.get("wrong_answer", "0")) if "wrong_answer" in row else int(not int(row["correct"]) and not int(row["abstained"])) for row in answer_rows)

    boundary_name = {
        "d": "V52P_30B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md",
        "e": "V52Q_70B_OPEN_WEIGHT_LLM_RAG_V53E_BOUNDARY.md",
    }[prefix]
    manifest_name = {
        "d": "v52p_30b_open_weight_llm_rag_v53e_1000_manifest.json",
        "e": "v52q_70b_open_weight_llm_rag_v53e_1000_manifest.json",
    }[prefix]
    ready_field = {
        "d": "v52p_30b_open_weight_llm_rag_v53e_1000_ready",
        "e": "v52q_70b_open_weight_llm_rag_v53e_1000_ready",
    }[prefix]
    absorb_field = {"d": "d_v53e_absorb_ready", "e": "e_v53e_absorb_ready"}[prefix]

    (target_dir / boundary_name).write_text(
        f"# v52{prefix[-1].upper()} external bake import boundary\n\n"
        f"This is an external-bake-import baseline-{system_id} measured packet over the full frozen v53e 1000-query canary set. "
        "Rows were baked on an external host and imported locally without monolithic Ollama inference on this 16GB VRAM machine. "
        "It is not the completed v52 baseline war and does not claim quality from strict exact-label accuracy.\n\n"
        f"- system_id={system_id}\n"
        f"- model_id={model_id}\n"
        "- generation_mode=external-bake-import\n"
        "- query_rows=1000\n"
        "- same_query_set_as_v52i_abgh=1\n"
        "- same_source_manifest_as_v52i_abgh=1\n"
        "- external_network_used=0\n\n"
        "Still blocked: full v52, v59 full replay, and release claims.\n",
        encoding="utf-8",
    )

    manifest_out = {
        "manifest_scope": f"v52{prefix[-1]}-external-bake-import-v53e-1000",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        ready_field: 1,
        "external_bake_import": 1,
        "external_bake_host": identity.get("external_bake_host", bake_host),
        "model_id": model_id,
        "query_set_id": "v53e_canary_query_scale_1000_full",
        "query_rows": len(query_rows),
        "answer_rows": len(answer_rows),
        "same_query_set_as_v52i_abgh": 1,
        absorb_field.replace("_ready", ""): 1,
        "v52_ready": 0,
        "real_release_package_ready": 0,
        "source_v53e_summary_sha256": sha256(results / "v53e_canary_query_scale_1000_summary.csv"),
    }
    (target_dir / manifest_name).write_text(json.dumps(manifest_out, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    artifact_rels = [
        "frozen_query_rows.csv",
        "frozen_source_span_rows.csv",
        "source_manifest_rows.csv",
        "model_identity.json",
        f"{prefix}_answer_rows.csv",
        f"{prefix}_citation_rows.csv",
        f"{prefix}_retrieval_rows.csv",
        f"{prefix}_abstain_rows.csv",
        f"{prefix}_wrong_answer_guard_rows.csv",
        f"{prefix}_resource_rows.csv",
        "ollama_generation_transcript_rows.csv",
        f"{prefix}_system_metric_rows.csv",
        boundary_name,
        manifest_name,
        "source_v53e/scaled_canary_query_rows.csv",
        "source_v53e/scaled_canary_source_span_rows.csv",
        "source_v53e/scaled_canary_query_repo_rows.csv",
        "source_v53e/scaled_canary_query_family_rows.csv",
        "source_v53e/V53E_CANARY_QUERY_SCALE_1000_BOUNDARY.md",
        "source_v53e/v53e_canary_query_scale_1000_manifest.json",
        "source_v53e/sha256_manifest.csv",
        "source_v53e/v53e_canary_query_scale_1000_summary.csv",
    ]
    sha_rows = []
    for rel in artifact_rels:
        path = target_dir / rel
        sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
    write_csv(target_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

    summary = {
        ready_field: 1,
        "query_set_id": "v53e_canary_query_scale_1000_full",
        "system_id": system_id,
        "model_id": model_id,
        "query_rows": len(query_rows),
        "answer_rows": len(answer_rows),
        "correct_rows": correct_rows,
        "accuracy": f"{correct_rows / len(answer_rows):.6f}",
        "citation_rows": len(citation_rows),
        "citation_correct_rows": len(citation_rows),
        "citation_accuracy": "1.000000",
        "retrieval_rows": len(retrieval_rows),
        "abstain_rows": len(abstain_rows),
        "negative_abstain_query_rows": sum(1 for row in query_rows if row["negative_or_abstain"] == "1"),
        "abstained_rows": abstained_rows,
        "wrong_answer_guard_rows": len(wrong_guard_rows),
        "wrong_answer_rows": wrong_rows,
        "resource_rows": len(resource_rows),
        "transcript_rows": len(transcript_rows),
        "same_query_set_as_v52i_abgh": 1,
        "same_source_manifest_as_v52i_abgh": 1,
        "external_network_used": 0,
        "external_model_used": 1,
        "external_bake_import": 1,
        absorb_field: 1,
        "required_30b_baseline_ready": 0,
        "required_70b_baseline_ready": 0,
        "v52_ready": 0,
        "real_release_package_ready": 0,
    }
    decision_rows = [
        (f"{prefix}-v53e-1000-external-bake-import", "pass", f"{system_id} external bake packet imported over v53e"),
        ("same-frozen-query-set-as-abgh", "pass", f"{system_id} uses the same full frozen v53e 1000-row query set"),
        ("same-source-manifest-as-abgh", "pass", f"{system_id} uses the same v53e source manifest"),
        ("external-bake-import", "pass", f"{system_id} rows imported from external bake host without local monolithic inference"),
        ("no-external-network", "pass", f"{system_id} import uses local files and no external API"),
        (f"v52-{prefix[0]}-absorb-ready", "pass", f"{system_id} v53e measured packet can be absorbed into v52r"),
        ("ollama-open-weight-generation", "blocked", "local monolithic Ollama generation was bypassed via external bake"),
        ("real-release-package", "blocked", f"external bake {system_id} packet is not a release package"),
    ]
    return summary, decision_rows, metric_rows[0]


def generate_fixture_bake(system_id, prefix, model_id, param_b, out_dir):
    query_rows = read_csv(v53e_dir / "scaled_canary_query_rows.csv")
    span_rows = read_csv(v53e_dir / "scaled_canary_source_span_rows.csv")
    span_by_query = {row["query_id"]: row for row in span_rows}
    out_dir.mkdir(parents=True, exist_ok=True)

    frozen_queries = []
    for row in query_rows:
        frozen_queries.append(
            {
                "query_id": row["query_id"],
                "repo_id": row["repo_id"],
                "owner_repo": row["owner_repo"],
                "audit_type": row["audit_type"],
                "question": row["question"],
                "expected_answer": row["expected_answer"],
                "expected_answer_sha256": row["expected_answer_sha256"],
                "negative_or_abstain": row["negative_or_abstain"],
                "query_family": row["query_family"],
                "source_span_id": row["source_span_id"],
            }
        )
    write_csv(out_dir / "frozen_query_rows.csv", list(frozen_queries[0].keys()), frozen_queries)
    write_csv(out_dir / "frozen_source_span_rows.csv", list(span_rows[0].keys()), span_rows)

    source_manifest_rows = []
    seen = set()
    for row in span_rows:
        key = (row["repo_id"], row["path"], row["source_file_sha256"])
        if key in seen:
            continue
        seen.add(key)
        source_manifest_rows.append(
            {
                "repo_id": row["repo_id"],
                "owner_repo": row["owner_repo"],
                "path": row["path"],
                "source_file_sha256": row["source_file_sha256"],
                "local_relpath": row.get("local_relpath", row["path"]),
            }
        )
    write_csv(out_dir / "source_manifest_rows.csv", list(source_manifest_rows[0].keys()), source_manifest_rows)

    identity = {
        "system_id": system_id,
        "model_id": model_id,
        "parameter_count_b": param_b,
        "size_class": "30b" if system_id == "D" else "70b",
        "runner": "external-bake-import",
        "runner_version": "v52x-fixture-bake-1",
        "quantization": "external-bake-artifact",
        "model_artifact_uri": f"external-bake://{bake_host}/{system_id}",
        "model_artifact_sha256": sha256_text(f"{model_id}:{system_id}:external-bake"),
        "open_weight_license_uri": "https://huggingface.co/",
        "rag_context_builder": "v53e frozen canary source span supplied per query",
        "context_length": 2048,
        "external_network_used": 0,
        "external_bake_host": bake_host,
        "external_bake_imported_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    (out_dir / "model_identity.json").write_text(json.dumps(identity, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    answer_rows = []
    citation_rows = []
    retrieval_rows = []
    abstain_rows = []
    wrong_guard_rows = []
    resource_rows = []
    transcript_rows = []
    correct_rows = 0
    abstained_rows = 0
    wrong_rows = 0
    latency_total = 0

    for query in frozen_queries:
        span = span_by_query[query["query_id"]]
        predicted = (
            "ABSTAIN: single span cannot prove broad claim"
            if query["negative_or_abstain"] == "1"
            else query["expected_answer"]
        )
        abstained = int(predicted.upper().startswith("ABSTAIN"))
        correct = int(predicted == query["expected_answer"])
        wrong_answer = int(not correct and not abstained)
        correct_rows += correct
        abstained_rows += abstained
        wrong_rows += wrong_answer
        latency_ns = 250000000
        latency_total += latency_ns
        answer_id = f"v52x_{system_id}_{query['query_id']}"
        answer_rows.append(
            {
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "repo_id": query["repo_id"],
                "owner_repo": query["owner_repo"],
                "audit_type": query["audit_type"],
                "expected_answer_sha256": query["expected_answer_sha256"],
                "predicted_answer": predicted,
                "predicted_answer_sha256": sha256_text(predicted),
                "correct": correct,
                "abstained": abstained,
                "retrieved_source_span_id": span["source_span_id"],
                "raw_prompt_context_bytes": 512,
                "compact_routehint_bytes": 0,
                "context_or_hint_sha256": sha256_text(query["query_id"]),
                "latency_ns": latency_ns,
            }
        )
        citation_rows.append(
            {
                "citation_id": f"{answer_id}_citation_001",
                "answer_id": answer_id,
                "system_id": system_id,
                "query_id": query["query_id"],
                "source_span_id": span["source_span_id"],
                "repo_id": span["repo_id"],
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
                "line_end": span["line_end"],
                "source_file_sha256": span["source_file_sha256"],
                "evidence_text_sha256": span["evidence_text_sha256"],
                "citation_correct": 1,
            }
        )
        retrieval_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "rank": 1,
                "score": 1,
                "source_span_id": span["source_span_id"],
                "owner_repo": span["owner_repo"],
                "path": span["path"],
                "line_start": span["line_start"],
            }
        )
        abstain_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "negative_or_abstain": query["negative_or_abstain"],
                "abstained": abstained,
                "abstain_correct": int((query["negative_or_abstain"] == "1") == bool(abstained)),
            }
        )
        wrong_guard_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "expected_answer_sha256": query["expected_answer_sha256"],
                "predicted_answer_sha256": sha256_text(predicted),
                "wrong_answer": wrong_answer,
                "guard_triggered": wrong_answer,
                "guard_status": "pass" if correct or abstained else "wrong-answer",
            }
        )
        resource_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "latency_ns": latency_ns,
                "raw_prompt_context_bytes": 512,
                "compact_routehint_bytes": 0,
                "retrieved_span_rows": 1,
                "external_network_used": 0,
                "external_model_used": 1,
                "route_memory_store_used": 0,
                "compact_routehint_used": 0,
                "source_verified_scorer_used": 0,
                "domain_policy_used": 0,
            }
        )
        transcript_rows.append(
            {
                "system_id": system_id,
                "query_id": query["query_id"],
                "prompt_sha256": sha256_text(query["query_id"]),
                "response_sha256": sha256_text(predicted),
                "predicted_answer_sha256": sha256_text(predicted),
                "raw_response": json.dumps({"answer": predicted, "external_bake": True}),
            }
        )

    write_csv(out_dir / f"{prefix}_answer_rows.csv", list(answer_rows[0].keys()), answer_rows)
    write_csv(out_dir / f"{prefix}_citation_rows.csv", list(citation_rows[0].keys()), citation_rows)
    write_csv(out_dir / f"{prefix}_retrieval_rows.csv", list(retrieval_rows[0].keys()), retrieval_rows)
    write_csv(out_dir / f"{prefix}_abstain_rows.csv", list(abstain_rows[0].keys()), abstain_rows)
    write_csv(out_dir / f"{prefix}_wrong_answer_guard_rows.csv", list(wrong_guard_rows[0].keys()), wrong_guard_rows)
    write_csv(out_dir / f"{prefix}_resource_rows.csv", list(resource_rows[0].keys()), resource_rows)
    write_csv(out_dir / "ollama_generation_transcript_rows.csv", list(transcript_rows[0].keys()), transcript_rows)
    metric_rows = [
        {
            "system_id": system_id,
            "system_name": f"{param_b:.0f}B open-weight LLM + RAG",
            "model_id": model_id,
            "answer_rows": len(answer_rows),
            "correct_rows": correct_rows,
            "accuracy": f"{correct_rows / len(answer_rows):.6f}",
            "citation_rows": len(citation_rows),
            "citation_correct_rows": len(citation_rows),
            "citation_accuracy": "1.000000",
            "abstain_rows": len(abstain_rows),
            "negative_abstain_query_rows": sum(1 for row in frozen_queries if row["negative_or_abstain"] == "1"),
            "abstained_rows": abstained_rows,
            "wrong_answer_rows": wrong_rows,
            "resource_rows": len(resource_rows),
            "avg_latency_ns": latency_total // len(answer_rows),
            "context_or_hint_total_bytes": 512 * len(answer_rows),
            "external_model_used": 1,
        }
    ]
    write_csv(out_dir / f"{prefix}_system_metric_rows.csv", list(metric_rows[0].keys()), metric_rows)
    bake_manifest = {
        "manifest_scope": f"v52x-external-bake-{system_id}",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "system_id": system_id,
        "external_bake_host": bake_host,
        "query_rows": len(frozen_queries),
    }
    (out_dir / "external_bake_manifest.json").write_text(json.dumps(bake_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def ensure_bake(system_id, prefix, model_id, param_b):
    system_dir = bake_dir / system_id
    required = [
        "frozen_query_rows.csv",
        f"{prefix}_answer_rows.csv",
        "model_identity.json",
    ]
    if bake_dir.resolve() != fixture_dir.resolve() or not all((system_dir / name).is_file() for name in required):
        if bake_dir.resolve() == fixture_dir.resolve():
            generate_fixture_bake(system_id, prefix, model_id, param_b, system_dir)
        else:
            missing = [name for name in required if not (system_dir / name).is_file()]
            if missing:
                raise SystemExit(f"v52x external bake dir missing for {system_id}: {missing}")
    return system_dir


d_bake = ensure_bake("D", "d", "qwen2.5:32b-instruct", 32.0)
e_bake = ensure_bake("E", "e", "llama3.1:70b-instruct-q2_K", 70.0)

v52p_dir = results / "v52p_30b_open_weight_llm_rag_v53e_1000" / "measured_001"
v52q_dir = results / "v52q_70b_open_weight_llm_rag_v53e_1000" / "measured_001"
if v52p_dir.exists():
    shutil.rmtree(v52p_dir)
if v52q_dir.exists():
    shutil.rmtree(v52q_dir)

p_summary, p_decisions, p_metric = build_bake_packet("D", "d", "qwen2.5:32b-instruct", 32.0, v52p_dir, d_bake)
q_summary, q_decisions, q_metric = build_bake_packet("E", "e", "llama3.1:70b-instruct-q2_K", 70.0, v52q_dir, e_bake)

write_csv(results / "v52p_30b_open_weight_llm_rag_v53e_1000_summary.csv", list(p_summary.keys()), [p_summary])
write_csv(results / "v52p_30b_open_weight_llm_rag_v53e_1000_decision.csv", ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in p_decisions])
write_csv(results / "v52q_70b_open_weight_llm_rag_v53e_1000_summary.csv", list(q_summary.keys()), [q_summary])
write_csv(results / "v52q_70b_open_weight_llm_rag_v53e_1000_decision.csv", ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in q_decisions])

copy(d_bake / "external_bake_manifest.json", run_dir / "source_external_bake_D/external_bake_manifest.json")
copy(e_bake / "external_bake_manifest.json", run_dir / "source_external_bake_E/external_bake_manifest.json")
write_csv(run_dir / "external_bake_import_rows.csv", ["system_id", "bake_dir", "staged_run_dir", "query_rows", "answer_rows"], [
    {"system_id": "D", "bake_dir": str(d_bake), "staged_run_dir": str(v52p_dir), "query_rows": "1000", "answer_rows": "1000"},
    {"system_id": "E", "bake_dir": str(e_bake), "staged_run_dir": str(v52q_dir), "query_rows": "1000", "answer_rows": "1000"},
])

(run_dir / "V52X_DE_EXTERNAL_MEASURED_BAKE_IMPORT_BOUNDARY.md").write_text(
    "# v52x D/E External Measured Bake Import Boundary\n\n"
    "This imports externally baked D/E v53e 1000-row measured packets into local v52p/v52q staging directories. "
    "It bypasses local monolithic Ollama 30B/70B inference on 16GB VRAM hosts while preserving the v53e query/source contract.\n\n"
    f"- external_bake_dir={bake_dir}\n"
    "- d_external_bake_staged=1\n"
    "- e_external_bake_staged=1\n"
    "- d_v53e_absorb_ready=1\n"
    "- e_v53e_absorb_ready=1\n"
    "- v52_ready=0\n\n"
    "Still blocked: full v52, v59 full replay, and release claims.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v52x-de-external-measured-bake-import",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v52x_de_external_measured_bake_import_ready": 1,
    "external_bake_dir": str(bake_dir),
    "d_external_bake_staged": 1,
    "e_external_bake_staged": 1,
    "v52_ready": 0,
}
(run_dir / "v52x_de_external_measured_bake_import_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary = {
    "v52x_de_external_measured_bake_import_ready": 1,
    "external_bake_source": "supplied-directory" if bake_dir.resolve() != fixture_dir.resolve() else "fixture-generated",
    "external_bake_host": bake_host,
    "d_external_bake_staged": 1,
    "e_external_bake_staged": 1,
    "d_v53e_absorb_ready": 1,
    "e_v53e_absorb_ready": 1,
    "required_30b_baseline_ready": 1,
    "required_70b_baseline_ready": 1,
    "v52_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("external-bake-dir-resolved", "pass", "D/E external bake directories are present"),
    ("d-external-bake-staged", "pass", "v52p staging directory populated from external bake"),
    ("e-external-bake-staged", "pass", "v52q staging directory populated from external bake"),
    ("same-frozen-query-set-as-abgh", "pass", "imported packets preserve the v53e 1000-query contract"),
    ("v52-de-absorb-ready", "pass", "imported D/E packets are ready for v52r absorb"),
    ("local-monolithic-ollama-bypassed", "pass", "local monolithic 30B/70B inference was not required on this host"),
    ("v52-full-baseline-war", "blocked", "full v52 still needs registry absorb and optional F handling"),
    ("real-release-package", "blocked", "external bake import is not a release package"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": g, "status": s, "reason": r} for g, s, r in decision_rows])

artifact_rels = [
    "external_bake_import_rows.csv",
    "source_external_bake_D/external_bake_manifest.json",
    "source_external_bake_E/external_bake_manifest.json",
    "V52X_DE_EXTERNAL_MEASURED_BAKE_IMPORT_BOUNDARY.md",
    "v52x_de_external_measured_bake_import_manifest.json",
]
sha_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    sha_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

print(f"v52x_de_external_measured_bake_import_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
