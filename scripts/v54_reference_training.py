#!/usr/bin/env python3
"""v54 reference training + generation-artifact emission (reference scaffold).

Adds, on top of the #21 reference scorer/generator, the training and emission
mechanics the v54 contracts describe:

    load_external_labels   read a labeled-candidate CSV into pairwise training
                           pairs and classify label provenance (local/file:// or
                           missing provenance => external_label_source_ready=0).
    train_pairwise_scorer  (re-exported) fit the linear route scorer.
    train_generator        deterministic numerical-gradient teacher-forced
                           training loop for the tiny non-attention GRU.
    checkpoint             serialize scorer/generator/config and hash it.
    validate_unseen        evaluate on a supplied unseen-repo eval set; keeps
                           heldout_metric_ready=0 unless a real source is given.
    emit_generation_rows   write v54f-schema free-running generation rows.

BOUNDARY (critical): this is an UNTRAINED-by-default REFERENCE scaffold, not
real generation evidence.

- The GRU is tiny and trained only on caller-supplied fixture sequences; its
  output is not a meaningful answer.
- load_external_labels keeps external_label_source_ready=0 for local/file:// or
  unprovenanced labels (mirrors the h10 real-teacher-source discipline).
- validate_unseen keeps heldout_metric_ready=0 unless real_source=True.
- emit_generation_rows produces schema-correct rows that satisfy the MECHANICAL
  constraints (free_running_decode=1, teacher_forcing_used=0,
  raw_prompt_context_bytes=0, source_locator_leakage=0, external_api_used=0) and
  leaves evaluator-only fields blank. It writes to a caller path only.
- Nothing here writes results/ admission artifacts, edits any contract, or flips
  readiness/typed_ready.json. real_model_generation_ready stays 0; v54 closure
  still requires a real model + verified external labels + heldout via the
  canonical experiments/test_v54f_*.sh intake.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from pathlib import Path

from free_running_generator_reference import (
    TinyGRUGenerator,
    build_model_visible_generator_input,
    encode_context,
)
from route_scorer_reference import feature_vector, train_pairwise_scorer

TRUE_TOKENS = {"1", "true", "yes"}
MATRIX_ATTRS = ["embedding", "w_z", "w_r", "w_h", "u_z", "u_r", "u_h", "w_o"]
VECTOR_ATTRS = ["b_z", "b_r", "b_h", "b_o"]


def read_rows(path: Path) -> tuple[list[str], list[dict]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


# --------------------------------------------------------------------------- #
# external-label loader (provenance gated)
# --------------------------------------------------------------------------- #
def load_external_labels(path: Path) -> tuple[list[tuple], dict]:
    """Build pairwise training pairs from a labeled-candidate CSV.

    Expected columns per row: pos_/neg_ candidate_score, evidence_probability,
    provenance_valid, candidate_count, plus source_uri, provenance_hash.

    Provenance is classified conservatively: any local/``file://`` source, any
    missing source_uri/provenance_hash, or any non-HTTPS source keeps
    ``external_label_source_ready=False`` (local labels are not real external
    teacher labels).
    """
    _, rows = read_rows(path)
    pairs: list[tuple] = []
    external_ready = bool(rows)
    for row in rows:
        pos = feature_vector(
            float(row["pos_candidate_score"]),
            float(row["pos_evidence_probability"]),
            (row.get("pos_provenance_valid") or "").lower() in TRUE_TOKENS,
            int(row["pos_candidate_count"]),
        )
        neg = feature_vector(
            float(row["neg_candidate_score"]),
            float(row["neg_evidence_probability"]),
            (row.get("neg_provenance_valid") or "").lower() in TRUE_TOKENS,
            int(row["neg_candidate_count"]),
        )
        pairs.append((pos, neg))
        uri = (row.get("source_uri") or "").strip().lower()
        prov = (row.get("provenance_hash") or "").strip()
        if not uri or not prov or not uri.startswith("https://"):
            external_ready = False
    return pairs, {"external_label_source_ready": external_ready, "label_rows": len(rows)}


# --------------------------------------------------------------------------- #
# GRU training loop (deterministic numerical gradient)
# --------------------------------------------------------------------------- #
def _param_slots(generator: TinyGRUGenerator) -> list[tuple[list, int]]:
    slots: list[tuple[list, int]] = []
    for name in MATRIX_ATTRS:
        for row in getattr(generator, name):
            for index in range(len(row)):
                slots.append((row, index))
    for name in VECTOR_ATTRS:
        vector = getattr(generator, name)
        for index in range(len(vector)):
            slots.append((vector, index))
    return slots


def _sequence_loss(generator: TinyGRUGenerator, sequence: list[int], context) -> float:
    hidden = generator.initial_hidden()
    token = sequence[0]
    total = 0.0
    count = 0
    for target in sequence[1:]:
        logits, hidden = generator.step(token, hidden, context)
        peak = max(logits)
        exps = [math.exp(value - peak) for value in logits]
        denom = sum(exps)
        prob = exps[target] / denom
        total += -math.log(prob + 1e-12)
        count += 1
        token = target  # teacher forcing
    return total / max(1, count)


def _dataset_loss(generator: TinyGRUGenerator, dataset: list[tuple[list[int], tuple]]) -> float:
    return sum(_sequence_loss(generator, seq, ctx) for seq, ctx in dataset) / max(1, len(dataset))


def train_generator(
    generator: TinyGRUGenerator,
    dataset: list[tuple[list[int], tuple]],
    *,
    learning_rate: float = 0.5,
    epochs: int = 6,
    epsilon: float = 1e-4,
) -> list[float]:
    """Teacher-forced training via deterministic central-difference gradients.

    Numerical gradients are used (instead of hand-written BPTT) so the reference
    trainer is correct by construction. Suited to the tiny demo sizes only.
    """
    slots = _param_slots(generator)
    history: list[float] = []
    for _ in range(epochs):
        history.append(_dataset_loss(generator, dataset))
        grads: list[float] = []
        for ref, index in slots:
            original = ref[index]
            ref[index] = original + epsilon
            loss_plus = _dataset_loss(generator, dataset)
            ref[index] = original - epsilon
            loss_minus = _dataset_loss(generator, dataset)
            ref[index] = original
            grads.append((loss_plus - loss_minus) / (2.0 * epsilon))
        for (ref, index), grad in zip(slots, grads):
            ref[index] -= learning_rate * grad
    history.append(_dataset_loss(generator, dataset))
    return history


# --------------------------------------------------------------------------- #
# checkpoint / config hash
# --------------------------------------------------------------------------- #
def checkpoint(
    generator: TinyGRUGenerator,
    scorer_weights,
    config: dict,
    path: Path,
) -> str:
    payload = {
        "config": config,
        "scorer_weights": list(scorer_weights),
        "generator": {name: getattr(generator, name) for name in MATRIX_ATTRS + VECTOR_ATTRS},
    }
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    digest = "sha256:" + hashlib.sha256(blob).hexdigest()
    out = {"checkpoint_sha256": digest, "boundary": "reference-scaffold-not-real-evidence", **payload}
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(out, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return digest


# --------------------------------------------------------------------------- #
# unseen-repo validation
# --------------------------------------------------------------------------- #
def validate_unseen(eval_rows: list[dict], *, real_source: bool = False) -> dict:
    total = len(eval_rows)
    correct = sum(
        1 for row in eval_rows if (row.get("predicted") or "").strip() == (row.get("expected") or "").strip()
    )
    repos = sorted({(row.get("repo_id") or "").strip() for row in eval_rows if (row.get("repo_id") or "").strip()})
    return {
        "eval_rows": total,
        "unseen_repos": len(repos),
        "exact_match": (correct / total) if total else 0.0,
        # Heldout metric is never real unless backed by a real unseen source.
        "heldout_metric_ready": bool(real_source),
    }


# --------------------------------------------------------------------------- #
# v54f-schema generation row writer
# --------------------------------------------------------------------------- #
def emit_generation_rows(
    generator: TinyGRUGenerator,
    columns: list[str],
    queries: list[dict],
    *,
    generator_id: str = "reference-tiny-gru",
    max_tokens: int = 12,
) -> list[dict]:
    bos = generator.vocab[generator.bos_token_id]
    eos = generator.vocab[generator.eos_token_id]
    rows: list[dict] = []
    for index, query in enumerate(queries, start=1):
        payload = build_model_visible_generator_input(
            {
                "sanitized_question": query["sanitized_question"],
                "opaque_routehint": query.get("opaque_routehint", ""),
            }
        )
        context = encode_context(payload, generator.context_dim)
        result = generator.free_running_decode(context, max_tokens=max_tokens)
        text = " ".join(token for token in result.tokens if token not in (bos, eos))
        row = {column: "" for column in columns}
        row["generation_id"] = f"gen-{index:06d}"
        row["query_id"] = query["query_id"]
        row["generator_id"] = generator_id
        row["corpus_snapshot_sha256"] = query.get("corpus_snapshot_sha256", "")
        row["sanitized_question_sha256"] = _sha256_text(query["sanitized_question"])
        row["free_running_decode"] = "1"
        row["teacher_forcing_used"] = "0"
        row["raw_prompt_context_bytes"] = "0"
        row["retrieved_text_in_prompt"] = "0"
        row["source_locator_leakage"] = "0"
        row["generated_text"] = text
        row["raw_output_sha256"] = _sha256_text(text)
        row["output_token_count"] = str(len(result.tokens))
        row["external_api_used"] = "0"
        # evaluator-only fields (answer_correct, citation_correct, abstain_correct,
        # wrong_answer, evaluator_version, latency_ns, peak_memory_mb, citation_handle)
        # are intentionally left blank for the evaluator to fill.
        rows.append(row)
    return rows


def _generation_columns(contract_path: Path) -> list[str]:
    data = json.loads(contract_path.read_text(encoding="utf-8"))
    for artifact in data.get("required_artifacts", []):
        if artifact["artifact_id"] == "free-running-generation-template-rows":
            return list(artifact["required_columns"])
    raise SystemExit(f"{contract_path}: free-running-generation-template-rows not found")


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def cmd_emit_generation(args: argparse.Namespace) -> int:
    columns = _generation_columns(Path(args.contract))
    _, query_rows = read_rows(Path(args.queries))
    vocab = ["<bos>", "<eos>", "alpha", "beta", "gamma", "delta"]
    generator = TinyGRUGenerator(vocab, embed_dim=4, hidden_dim=4, context_dim=4, seed=args.seed)
    rows = emit_generation_rows(generator, columns, query_rows)
    write_csv(Path(args.out), columns, rows)
    print(
        f"wrote {len(rows)} REFERENCE free-running generation rows to {args.out} "
        f"(fixture; real_model_generation_ready stays 0)"
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_emit = sub.add_parser("emit-generation", help="write v54f-schema reference generation rows")
    p_emit.add_argument(
        "--contract",
        default="v54/free_running_generation_evidence_intake_contract.json",
        help="v54f contract (generation row column source of truth)",
    )
    p_emit.add_argument("--queries", required=True, help="CSV with query_id, sanitized_question[, opaque_routehint]")
    p_emit.add_argument("--out", required=True, help="output generation rows CSV")
    p_emit.add_argument("--seed", type=int, default=0)
    p_emit.set_defaults(func=cmd_emit_generation)
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
