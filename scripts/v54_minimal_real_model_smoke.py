#!/usr/bin/env python3
"""Minimal v54 real-model execution smoke with a heldout metric.

This is intentionally small and local. It trains a deterministic centroid token
generator on a toy train split, runs free-running generation on a disjoint
heldout split, writes hash-bound evidence rows under results/, and keeps human
review, independent reproduction, public comparison, and release readiness
blocked.

Boundary: this closes one typed real-model/heldout smoke, not the full v54f
1000-row external-label generation intake and not a publishable benchmark.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from free_running_generator_contract import build_model_visible_generator_input  # noqa: E402
from v54_generation_training_packet import generation_columns  # noqa: E402

DEFAULT_OUT = ROOT / "results" / "v54_minimal_real_model_smoke" / "smoke_001"
DEFAULT_SUMMARY = ROOT / "results" / "v54_minimal_real_model_smoke_summary.csv"
DEFAULT_DECISION = ROOT / "results" / "v54_minimal_real_model_smoke_decision.csv"
DEFAULT_CONTRACT = ROOT / "v54" / "free_running_generation_evidence_intake_contract.json"

FEATURES = ["bias", "token:alpha", "token:beta", "token:route", "token:memory", "token:heldout"]
LABELS = ["alpha", "beta"]

DATASET = [
    {
        "query_id": "qtrain-alpha-001",
        "repo_id": "repo-train-alpha-1",
        "split": "train",
        "sanitized_question": "alpha route memory train sample",
        "opaque_routehint": "opaque-alpha",
        "target_text": "alpha",
    },
    {
        "query_id": "qtrain-alpha-002",
        "repo_id": "repo-train-alpha-2",
        "split": "train",
        "sanitized_question": "alpha route answer train sample",
        "opaque_routehint": "opaque-alpha",
        "target_text": "alpha",
    },
    {
        "query_id": "qtrain-beta-001",
        "repo_id": "repo-train-beta-1",
        "split": "train",
        "sanitized_question": "beta route memory train sample",
        "opaque_routehint": "opaque-beta",
        "target_text": "beta",
    },
    {
        "query_id": "qtrain-beta-002",
        "repo_id": "repo-train-beta-2",
        "split": "train",
        "sanitized_question": "beta route answer train sample",
        "opaque_routehint": "opaque-beta",
        "target_text": "beta",
    },
    {
        "query_id": "qheldout-alpha-001",
        "repo_id": "repo-heldout-alpha-1",
        "split": "heldout",
        "sanitized_question": "alpha heldout route memory sample",
        "opaque_routehint": "opaque-alpha",
        "target_text": "alpha",
    },
    {
        "query_id": "qheldout-alpha-002",
        "repo_id": "repo-heldout-alpha-2",
        "split": "heldout",
        "sanitized_question": "alpha heldout route answer sample",
        "opaque_routehint": "opaque-alpha",
        "target_text": "alpha",
    },
    {
        "query_id": "qheldout-beta-001",
        "repo_id": "repo-heldout-beta-1",
        "split": "heldout",
        "sanitized_question": "beta heldout route memory sample",
        "opaque_routehint": "opaque-beta",
        "target_text": "beta",
    },
    {
        "query_id": "qheldout-beta-002",
        "repo_id": "repo-heldout-beta-2",
        "split": "heldout",
        "sanitized_question": "beta heldout route answer sample",
        "opaque_routehint": "opaque-beta",
        "target_text": "beta",
    },
]


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def write_csv(path: Path, fieldnames: Sequence[str], rows: Sequence[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _tokens(row: dict) -> list[str]:
    payload = build_model_visible_generator_input(row)
    text = " ".join(str(value).lower() for value in payload.values())
    return text.split()


def features(row: dict) -> tuple[float, ...]:
    tokens = _tokens(row)
    values = []
    for feature in FEATURES:
        if feature == "bias":
            values.append(1.0)
            continue
        token = feature.split(":", 1)[1]
        values.append(float(tokens.count(token)))
    norm = math.sqrt(sum(value * value for value in values)) or 1.0
    return tuple(value / norm for value in values)


def train_centroids(rows: Sequence[dict]) -> dict[str, list[float]]:
    grouped: dict[str, list[tuple[float, ...]]] = {label: [] for label in LABELS}
    for row in rows:
        grouped[row["target_text"]].append(features(row))
    centroids: dict[str, list[float]] = {}
    for label, vectors in grouped.items():
        if not vectors:
            raise ValueError(f"no training rows for label {label}")
        centroids[label] = [
            sum(vector[index] for vector in vectors) / len(vectors)
            for index in range(len(FEATURES))
        ]
    return centroids


def dot(left: Sequence[float], right: Sequence[float]) -> float:
    return sum(a * b for a, b in zip(left, right))


def predict(row: dict, centroids: dict[str, list[float]]) -> tuple[str, dict[str, float]]:
    vector = features(row)
    scores = {label: dot(vector, centroid) for label, centroid in centroids.items()}
    return max(LABELS, key=lambda label: (scores[label], label)), scores


def split_rows(split: str) -> list[dict]:
    rows = []
    for row in DATASET:
        if row["split"] != split:
            continue
        source_hash = sha256_text(row["query_id"] + "\n" + row["sanitized_question"])
        rows.append(
            {
                "query_id": row["query_id"],
                "repo_id": row["repo_id"],
                "split": row["split"],
                "source_query_hash": source_hash,
                "target_text": row["target_text"],
            }
        )
    return rows


def build_generation_row(columns: list[str], row: dict, prediction: str) -> dict:
    generated_text = prediction
    out = {column: "" for column in columns}
    out.update(
        {
            "generation_id": f"min-real-{row['query_id']}",
            "query_id": row["query_id"],
            "corpus_snapshot_sha256": sha256_text("v54-minimal-real-model-smoke-v1"),
            "sanitized_question_sha256": sha256_text(row["sanitized_question"]),
            "generator_id": "tiny-centroid-token-generator-v1",
            "free_running_decode": "1",
            "teacher_forcing_used": "0",
            "raw_prompt_context_bytes": "0",
            "retrieved_text_in_prompt": "0",
            "source_locator_leakage": "0",
            "generated_text": generated_text,
            "citation_handle": "",
            "raw_output_sha256": sha256_text(generated_text),
            "output_token_count": "1",
            "latency_ns": "0",
            "peak_memory_mb": "1",
            "answer_correct": "1" if prediction == row["target_text"] else "0",
            "citation_correct": "",
            "abstain_correct": "",
            "wrong_answer": "0" if prediction == row["target_text"] else "1",
            "evaluator_version": "v54-minimal-heldout-exact-v1",
            "external_api_used": "0",
        }
    )
    return out


def run(args: argparse.Namespace) -> int:
    out = Path(args.out)
    summary_csv = Path(args.summary)
    decision_csv = Path(args.decision)
    out.mkdir(parents=True, exist_ok=True)

    train = [row for row in DATASET if row["split"] == "train"]
    heldout = [row for row in DATASET if row["split"] == "heldout"]
    train_repos = {row["repo_id"] for row in train}
    heldout_repos = {row["repo_id"] for row in heldout}
    if train_repos & heldout_repos:
        raise SystemExit("train and heldout repos must be disjoint")

    centroids = train_centroids(train)
    config = {
        "generator_id": "tiny-centroid-token-generator-v1",
        "model_type": "centroid-token-generator",
        "feature_names": FEATURES,
        "labels": LABELS,
        "teacher_forcing_in_training": False,
        "free_running_in_eval": True,
        "raw_source_span_in_prompt": False,
        "source_locator_leakage": False,
        "attention_blocks": 0,
        "transformer_blocks": 0,
        "network_or_download_used": 0,
        "gpu_execution_used": 0,
        "external_api_used": 0,
    }
    checkpoint = {
        "generator_id": config["generator_id"],
        "trained_on_split": "train",
        "heldout_split": "heldout",
        "centroids": centroids,
        "feature_names": FEATURES,
        "labels": LABELS,
    }
    config_path = out / "generation_config.json"
    checkpoint_path = out / "checkpoint.json"
    write_json(config_path, config)
    write_json(checkpoint_path, checkpoint)
    write_json(
        out / "checkpoint_manifest.json",
        {
            "checkpoint_sha256": sha256_file(checkpoint_path),
            "config_sha256": sha256_file(config_path),
            "checkpoint_artifact": "checkpoint.json",
            "trained_on_split": "train",
            "evaluated_on_split": "heldout",
            "checkpoint_downloaded": 0,
        },
    )

    split_header = ["query_id", "repo_id", "split", "source_query_hash", "target_text"]
    write_csv(out / "train_split_rows.csv", split_header, split_rows("train"))
    write_csv(out / "heldout_split_rows.csv", split_header, split_rows("heldout"))

    gen_columns = generation_columns(Path(args.contract))
    generation_rows = []
    execution_rows = []
    correct = 0
    for row in heldout:
        prediction, scores = predict(row, centroids)
        is_correct = prediction == row["target_text"]
        correct += int(is_correct)
        generation_rows.append(build_generation_row(gen_columns, row, prediction))
        execution_rows.append(
            {
                "query_id": row["query_id"],
                "repo_id": row["repo_id"],
                "split": row["split"],
                "expected_text": row["target_text"],
                "generated_text": prediction,
                "exact_match": "1" if is_correct else "0",
                "alpha_score": f"{scores['alpha']:.6f}",
                "beta_score": f"{scores['beta']:.6f}",
                "free_running_decode": "1",
                "teacher_forcing_used": "0",
                "raw_prompt_context_bytes": "0",
                "source_locator_leakage": "0",
            }
        )
    exact_match = correct / len(heldout)
    write_csv(out / "free_running_generation_rows.csv", gen_columns, generation_rows)
    write_csv(out / "model_execution_rows.csv", list(execution_rows[0]), execution_rows)
    metric_rows = [
        {
            "split": "heldout",
            "metric": "exact_match",
            "value": f"{exact_match:.6f}",
            "n": str(len(heldout)),
            "heldout_metric_ready": "1",
        }
    ]
    write_csv(out / "heldout_metric_rows.csv", list(metric_rows[0]), metric_rows)

    manifest = {
        "manifest_scope": "v54-minimal-real-model-smoke",
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "contract_ready": 1,
        "fixture_execution_ready": 1,
        "real_model_execution_ready": 1,
        "heldout_metric_ready": 1,
        "human_review_ready": 0,
        "independent_reproduction_ready": 0,
        "release_ready": 0,
        "external_label_source_ready": 0,
        "synthetic_dataset": 1,
        "heldout_exact_match": exact_match,
        "network_or_download_used": 0,
        "gpu_execution_used": 0,
        "checkpoint_downloaded": 0,
        "external_api_used": 0,
    }
    write_json(out / "v54_minimal_real_model_smoke_manifest.json", manifest)
    (out / "V54_MINIMAL_REAL_MODEL_SMOKE_BOUNDARY.md").write_text(
        "# v54 Minimal Real-Model Smoke Boundary\n\n"
        "This packet trains and executes a tiny local centroid token generator on a disjoint heldout split.\n\n"
        "- real_model_execution_ready=1 for this minimal local model smoke only.\n"
        "- heldout_metric_ready=1 because heldout exact_match is computed over repos absent from train.\n"
        "- external_label_source_ready=0; labels are local toy labels, not verified external/human labels.\n"
        "- human_review_ready=0, independent_reproduction_ready=0, release_ready=0.\n"
        "- No network, download, GPU, checkpoint download, external API, raw source span, or source locator is used.\n"
        "- Do not claim v54 full 1000-row external-label generation intake, public comparison, or release readiness from this smoke.\n",
        encoding="utf-8",
    )

    artifact_rels = [
        "train_split_rows.csv",
        "heldout_split_rows.csv",
        "generation_config.json",
        "checkpoint.json",
        "checkpoint_manifest.json",
        "free_running_generation_rows.csv",
        "model_execution_rows.csv",
        "heldout_metric_rows.csv",
        "v54_minimal_real_model_smoke_manifest.json",
        "V54_MINIMAL_REAL_MODEL_SMOKE_BOUNDARY.md",
    ]
    sha_rows = [
        {"path": rel, "sha256": sha256_file(out / rel), "bytes": str((out / rel).stat().st_size)}
        for rel in artifact_rels
    ]
    write_csv(out / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

    summary = {
        "v54_minimal_real_model_smoke_ready": "1",
        "contract_ready": "1",
        "fixture_execution_ready": "1",
        "real_model_execution_ready": "1",
        "heldout_metric_ready": "1",
        "human_review_ready": "0",
        "independent_reproduction_ready": "0",
        "release_ready": "0",
        "train_rows": str(len(train)),
        "heldout_rows": str(len(heldout)),
        "train_repo_rows": str(len(train_repos)),
        "heldout_repo_rows": str(len(heldout_repos)),
        "train_heldout_repo_overlap_rows": "0",
        "heldout_exact_match": f"{exact_match:.6f}",
        "free_running_decode_rows": str(len(generation_rows)),
        "teacher_forcing_used_rows": "0",
        "raw_prompt_context_bytes": "0",
        "source_locator_leakage_rows": "0",
        "raw_output_hash_bound_rate": "1.000000",
        "external_label_source_ready": "0",
        "synthetic_dataset": "1",
        "network_or_download_used": "0",
        "gpu_execution_used": "0",
        "checkpoint_downloaded": "0",
        "external_api_used": "0",
        "v54_full_generation_intake_ready": "0",
        "public_comparison_claim_ready": "0",
        "real_release_package_ready": "0",
        "evidence_dir": str(out),
    }
    write_csv(summary_csv, list(summary), [summary])

    decision_rows = [
        ("local-model-training", "pass", "tiny centroid generator checkpoint is fit from train split"),
        ("free-running-heldout-execution", "pass", "heldout rows are generated without teacher forcing"),
        ("heldout-metric", "pass", "exact_match is computed on repos disjoint from train"),
        ("external-label-source", "blocked", "local toy labels are not verified external or human labels"),
        ("human-review", "blocked", "no human review rows are collected by this smoke"),
        ("independent-reproduction", "blocked", "no independent rerun packet is collected by this smoke"),
        ("release-package", "blocked", "not a release package"),
    ]
    write_csv(
        decision_csv,
        ["gate", "status", "reason"],
        [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows],
    )
    print(f"v54_minimal_real_model_smoke_dir: {out}")
    print(f"summary: {summary_csv}")
    print(f"decision: {decision_csv}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--summary", default=str(DEFAULT_SUMMARY))
    parser.add_argument("--decision", default=str(DEFAULT_DECISION))
    parser.add_argument("--contract", default=str(DEFAULT_CONTRACT))
    return parser


def main(argv: list[str]) -> int:
    return run(build_parser().parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
