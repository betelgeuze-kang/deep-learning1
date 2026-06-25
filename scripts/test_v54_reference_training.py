"""Deterministic smoke test for scripts/v54_reference_training.py.

Reference scaffold only: trains a tiny GRU on fixture sequences, checks the
external-label provenance gate, checkpoint hashing, unseen validation, and that
emitted v54f generation rows satisfy the mechanical constraints while keeping
real flags off. No results/ artifacts, no readiness changes.

Run:  python3 scripts/test_v54_reference_training.py
"""
from __future__ import annotations

import csv
import sys
import tempfile
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parent
ROOT = SCRIPTS_DIR.parent
CONTRACT = ROOT / "v54" / "free_running_generation_evidence_intake_contract.json"

if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from free_running_generator_reference import TinyGRUGenerator  # noqa: E402
from route_scorer_reference import train_pairwise_scorer  # noqa: E402
from v54_reference_training import (  # noqa: E402
    _generation_columns,
    checkpoint,
    emit_generation_rows,
    load_external_labels,
    train_generator,
    validate_unseen,
)


def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=header, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


LABEL_HEADER = [
    "pos_candidate_score", "pos_evidence_probability", "pos_provenance_valid", "pos_candidate_count",
    "neg_candidate_score", "neg_evidence_probability", "neg_provenance_valid", "neg_candidate_count",
    "source_uri", "provenance_hash",
]


def _label_row(uri: str, prov: str) -> dict:
    return {
        "pos_candidate_score": "0.9", "pos_evidence_probability": "0.9",
        "pos_provenance_valid": "true", "pos_candidate_count": "3",
        "neg_candidate_score": "0.2", "neg_evidence_probability": "0.2",
        "neg_provenance_valid": "false", "neg_candidate_count": "3",
        "source_uri": uri, "provenance_hash": prov,
    }


def test_external_label_loader(tmp: Path) -> None:
    # Local file:// labels are NOT real external labels.
    local = tmp / "local_labels.csv"
    write_csv(local, LABEL_HEADER, [_label_row("file:///tmp/x.csv", "abc"), _label_row("", "")])
    pairs, meta = load_external_labels(local)
    assert len(pairs) == 2
    assert meta["external_label_source_ready"] is False
    # The scorer still trains on the pairs (mechanics work regardless).
    result = train_pairwise_scorer(pairs, epochs=100, learning_rate=0.2)
    assert result.loss_history[-1] < result.loss_history[0]

    # HTTPS + provenance hash classifies as external-ready (mechanism only).
    https = tmp / "https_labels.csv"
    write_csv(https, LABEL_HEADER, [_label_row("https://example.org/labels.csv", "deadbeef")])
    _, meta2 = load_external_labels(https)
    assert meta2["external_label_source_ready"] is True
    print("external-label loader: provenance gating OK")


def _make_generator() -> TinyGRUGenerator:
    return TinyGRUGenerator(["<bos>", "<eos>", "a", "b", "c"], embed_dim=2, hidden_dim=2, context_dim=2, seed=3)


def test_train_generator_and_checkpoint(tmp: Path) -> None:
    generator = _make_generator()
    context = (0.5, -0.5)
    # Teach a couple of short fixed sequences (bos ... eos).
    v = generator.token_to_id
    dataset = [
        ([v["<bos>"], v["a"], v["b"], v["<eos>"]], context),
        ([v["<bos>"], v["a"], v["c"], v["<eos>"]], context),
    ]
    history = train_generator(generator, dataset, learning_rate=0.5, epochs=6)
    assert history[-1] < history[0], "teacher-forced training must reduce loss"

    config = {"vocab": list(generator.vocab), "embed_dim": 2, "hidden_dim": 2, "context_dim": 2, "seed": 3}
    digest1 = checkpoint(generator, [0.1, 0.2, 0.3, 0.4], config, tmp / "ckpt.json")
    assert digest1.startswith("sha256:") and (tmp / "ckpt.json").is_file()
    # Deterministic: re-hashing the same state reproduces the digest.
    digest2 = checkpoint(generator, [0.1, 0.2, 0.3, 0.4], config, tmp / "ckpt2.json")
    assert digest1 == digest2
    print("train_generator + checkpoint: loss down + deterministic hash OK")


def test_validate_unseen() -> None:
    rows = [
        {"repo_id": "r1", "query_id": "q1", "predicted": "x", "expected": "x"},
        {"repo_id": "r1", "query_id": "q2", "predicted": "y", "expected": "z"},
        {"repo_id": "r2", "query_id": "q3", "predicted": "w", "expected": "w"},
    ]
    report = validate_unseen(rows, real_source=False)
    assert report["eval_rows"] == 3 and report["unseen_repos"] == 2
    assert abs(report["exact_match"] - (2 / 3)) < 1e-9
    assert report["heldout_metric_ready"] is False, "heldout must stay false without a real source"
    print("validate_unseen: metric + heldout-blocked OK")


def test_emit_generation_rows(tmp: Path) -> None:
    columns = _generation_columns(CONTRACT)
    generator = _make_generator()
    queries = [
        {"query_id": "q0001", "sanitized_question": "what does the function return", "opaque_routehint": "rh-1"},
        {"query_id": "q0002", "sanitized_question": "where is the config loaded", "opaque_routehint": "rh-2"},
    ]
    rows = emit_generation_rows(generator, columns, queries)
    assert len(rows) == 2
    for row in rows:
        assert set(row) == set(columns)
        assert row["free_running_decode"] == "1"
        assert row["teacher_forcing_used"] == "0"
        assert row["raw_prompt_context_bytes"] == "0"
        assert row["source_locator_leakage"] == "0"
        assert row["external_api_used"] == "0"
        assert row["raw_output_sha256"].startswith("sha256:")
        # evaluator-only fields stay blank for the evaluator.
        assert row["answer_correct"] == "" and row["evaluator_version"] == ""
    print("emit_generation_rows: v54f schema + mechanical constraints OK (fixture)")


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        test_external_label_loader(tmp)
        test_train_generator_and_checkpoint(tmp)
        test_validate_unseen()
        test_emit_generation_rows(tmp)
    print("v54 reference training smoke OK (reference scaffold; not real generation evidence)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
